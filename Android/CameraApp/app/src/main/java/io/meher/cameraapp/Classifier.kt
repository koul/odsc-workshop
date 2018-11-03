package io.meher.cameraapp

import android.content.res.AssetManager
import android.graphics.*
import android.os.SystemClock
import org.tensorflow.lite.Interpreter
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import java.io.*
import java.nio.ByteBuffer
import java.nio.ByteOrder
import android.support.v4.graphics.BitmapCompat
import io.fotoapparat.preview.Frame
import java.lang.Float
import java.nio.FloatBuffer
import java.util.*
import kotlin.experimental.and


class Recognition(
        /**
         * A unique identifier for what has been recognized. Specific to the class, not the instance of
         * the object.
         */
        val id: String?,
        /**
         * Display name for the recognition.
         */
        val title: String?,
        /**
         * A sortable score for how good the recognition is relative to others. Higher should be better.
         */
        val confidence: kotlin.Float?) {

    override fun toString(): String {
        var resultString = ""
        if (id != null) {
            resultString += "[$id] "
        }

        if (title != null) {
            resultString += "$title "
        }

        if (confidence != null) {
            resultString += String.format("(%.1f%%) ", confidence * 100.0f)
        }

        return resultString.trim { it <= ' ' }
    }
}

class Classifier {
    private val INPUT_SIZE = 224

    private val interpreter: Interpreter
    private val labelsList: List<String>

    constructor(assetManager: AssetManager, modelPath: String, labelsPath: String) {
        this.labelsList = this.getLabelsList(assetManager, labelsPath)!!
        val mappedBuffer = this.loadModelFile(assetManager, modelPath)!!
        this.interpreter = Interpreter(mappedBuffer)
    }

    fun classify(frame: Frame): Pair<List<Recognition>, Long> {
        val yuvImage = YuvImage(frame.image, ImageFormat.NV21, frame.size.width, frame.size.height, null)
        val outputStream = ByteArrayOutputStream()
        yuvImage.compressToJpeg(Rect(0, 0, frame.size.width, frame.size.height), 100, outputStream)
        val jpegByteArray = outputStream.toByteArray()
        var bitmap = BitmapFactory.decodeByteArray(jpegByteArray, 0, jpegByteArray.size)
        bitmap = Bitmap.createScaledBitmap(bitmap, INPUT_SIZE, INPUT_SIZE, false)
        val imageBuffer = this.getByteBuffer(bitmap)
        val result = Array(1) { ByteArray(this.labelsList.size) }
        //val result = Array(1) { FloatArray(this.labelsList.size) }
        val startTime = SystemClock.uptimeMillis()
        this.interpreter.run(imageBuffer, result)
        val endTime = SystemClock.uptimeMillis()
        val elapsedTime = endTime - startTime
        return Pair(getSortedResult(result), elapsedTime)
    }

    private fun loadModelFile(assetManager: AssetManager, modelPath: String): MappedByteBuffer? {
        try {
            val fileDescriptor = assetManager.openFd(modelPath)
            val inputStream = FileInputStream(fileDescriptor.fileDescriptor)
            val fileChannel = inputStream.channel
            val startOffset = fileDescriptor.startOffset
            val declaredLength = fileDescriptor.declaredLength
            return fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength)
        } catch (e: FileNotFoundException) {
            print(e)
        } catch (e: IOException) {
            print (e)
        }

        return null
    }

    private fun getLabelsList(assetManager: AssetManager, labelsPath: String): List<String>? {
        try {
            val inputStream = assetManager.open(labelsPath)
            //val inputStream = FileInputStream(fileDescriptor.fileDescriptor)
            val inputStreamReader = InputStreamReader(inputStream)
            val reader = BufferedReader(inputStreamReader)
            return reader.readLines()
        } catch (e: FileNotFoundException) {
            print(e)
        } catch (e: IOException) {
            print (e)
        }

        return null
    }

    private fun getByteBuffer(bitmap: Bitmap): ByteBuffer {
        val size = INPUT_SIZE * INPUT_SIZE * 3
        print (size)
        val byteBuffer = ByteBuffer.allocateDirect(size)
        byteBuffer.order(ByteOrder.nativeOrder())
        val intValues = IntArray(INPUT_SIZE * INPUT_SIZE)
        bitmap.getPixels(intValues, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
        var pixel = 0
        for (i in 0 until bitmap.width) {
            for (j in 0 until bitmap.height) {
                val pixelValue = intValues[pixel++]
                byteBuffer.put((pixelValue shr 16 and 0xFF).toByte())
                byteBuffer.put((pixelValue shr 8 and 0xFF).toByte())
                byteBuffer.put((pixelValue and 0xFF).toByte())
            }
        }

        return byteBuffer
    }

    private fun getSortedResult(labelProbArray: Array<ByteArray>): List<Recognition> {

        val pq = PriorityQueue<Recognition>(
                10,
                Comparator<Recognition> { lhs, rhs -> Float.compare(rhs.confidence!!, lhs.confidence!!) })

        for (i in this.labelsList.indices) {
            val confidence = (labelProbArray[0][i] and 0xff.toByte()) / 255.0f
            if (confidence > 0.1) {
                pq.add(Recognition("" + i,
                        if (this.labelsList.size > i) this.labelsList.get(i) else "unknown",
                        confidence))
            }
        }

        val recognitions = ArrayList<Recognition>()
        val recognitionsSize = Math.min(pq.size, 10)
        for (i in 0 until recognitionsSize) {
            recognitions.add(pq.poll())
        }

        return recognitions
    }

    private fun getSortedResult(labelProbArray: Array<FloatArray>): List<Recognition> {

        val pq = PriorityQueue<Recognition>(
                10,
                Comparator<Recognition> { lhs, rhs -> Float.compare(rhs.confidence!!, lhs.confidence!!) })

        for (i in this.labelsList.indices) {
            val confidence = (labelProbArray[0][i]) / 255.0f
            if (confidence > 0.1) {
                pq.add(Recognition("" + i,
                        if (this.labelsList.size > i) this.labelsList.get(i) else "unknown",
                        confidence))
            }
        }

        val recognitions = ArrayList<Recognition>()
        val recognitionsSize = Math.min(pq.size, 10)
        for (i in 0 until recognitionsSize) {
            recognitions.add(pq.poll())
        }

        return recognitions
    }
}