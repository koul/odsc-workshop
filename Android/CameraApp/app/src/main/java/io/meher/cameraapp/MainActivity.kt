package io.meher.cameraapp

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.widget.TextView
import io.fotoapparat.Fotoapparat
import io.fotoapparat.characteristic.LensPosition
import io.fotoapparat.parameter.ScaleType
import io.fotoapparat.view.CameraView
import android.os.SystemClock
import io.fotoapparat.configuration.CameraConfiguration
import io.fotoapparat.parameter.Resolution
import io.fotoapparat.selector.*


class MainActivity : AppCompatActivity() {
    private var fotoapparat: Fotoapparat? = null
    private var classifier: Classifier? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val cameraView: CameraView = findViewById(R.id.cameraView)
        val predictionLabel: TextView = findViewById(R.id.predictionLabel)

        //this.classifier = Classifier(this.assets, "resnet.tflite", "imagenet_classes.txt")
        this.classifier = Classifier(this.assets, "mobilenet_v1_1.0_224_quant.tflite", "imagenet_classes.txt")

        val cameraConfiguration = CameraConfiguration()

        var timeString = ""
        var count = 0

        this.fotoapparat = Fotoapparat.with(this)
            .into(cameraView)
            .previewScaleType(ScaleType.CenterCrop)
            .lensPosition { LensPosition.Back }
            .frameProcessor {frame ->
                val startTime = SystemClock.uptimeMillis()
                val results = this.classifier!!.classify(frame)
                val endTime = SystemClock.uptimeMillis()
                val elapsedTimeString = "${endTime - startTime} ms"
                val tensorFlowTime = "${results.second} ms"
                timeString += "${results.second}\n"
                count++
                if (count == 15) {
                    System.out.print(timeString)
                    count = 0
                    timeString = ""
                }

                runOnUiThread {
                    predictionLabel.text = elapsedTimeString + " " + tensorFlowTime + " " + results.first.toString()
                }
            }
            .build()
    }

    override fun onStart() {
        super.onStart()
        this.fotoapparat?.start()
    }

    override fun onStop() {
        super.onStop()
        this.fotoapparat?.stop()
    }
}
