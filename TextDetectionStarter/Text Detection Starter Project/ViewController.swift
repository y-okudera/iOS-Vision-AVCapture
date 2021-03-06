//
//  ViewController.swift
//  Text Detection Starter Project
//
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    private var session = AVCaptureSession()
    private let stillImageOutput = AVCapturePhotoOutput()
    private var request = [VNRequest]()
    private var lastObservation: VNRectangleObservation?
    private var sequenceHandler = VNSequenceRequestHandler()
    private var rectangleLayer: CAShapeLayer?
    private var pathLayer: CALayer?
    private lazy var cameraButton: UIButton = {
       let button = UIButton()
        button.layer.cornerRadius = 10.0
        let x = imageView.bounds.width / 2 - 25
        let y = imageView.bounds.height + 25
        button.frame = CGRect(x: x, y: y, width: 100, height: 50)
        button.setTitle("Capture", for: .normal)
        button.setTitleColor(UIColor.blue, for: .normal)
        button.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        return button
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        startLiveVideo()
        stillImageSetting()
        startTextDetection()
        view.addSubview(cameraButton)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
 
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        imageView.layer.sublayers?[0].frame = imageView.bounds
    }
    @objc private func capturePhoto() {
        print("Capture Capture")
        let photoSettings = AVCapturePhotoSettings()
        photoSettings.isAutoStillImageStabilizationEnabled = true
        photoSettings.isHighResolutionPhotoEnabled = true
        photoSettings.flashMode = .auto
        stillImageOutput.capturePhoto(with: photoSettings, delegate: self)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension ViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let imageData = photo.fileDataRepresentation()
        guard let data = imageData,
              let photo = UIImage(data: data)  else {
            return
        }
        let handleVC = HandlePhotoViewController.make(photo: photo)
        navigationController?.pushViewController(handleVC, animated: true)
    }
    @objc private func processVision() {
        print("Do Vision and Cut busniess card")
    }
}
extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    private func stillImageSetting() {
        stillImageOutput.isHighResolutionCaptureEnabled = true
        session.addOutput(stillImageOutput)
    }
    private func startLiveVideo() {
        session.sessionPreset = AVCaptureSession.Preset.photo
        let captureDevice = AVCaptureDevice.default(for: .video)
        let deviceInput = try! AVCaptureDeviceInput(device: captureDevice!)
        let deviceOutput = AVCaptureVideoDataOutput()
        deviceOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        deviceOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: DispatchQoS.QoSClass.default))
        session.addInput(deviceInput)
        session.addOutput(deviceOutput)
        
        let imageLayer = AVCaptureVideoPreviewLayer(session: session)
        imageLayer.frame = imageView.bounds
        imageView.layer.addSublayer(imageLayer)
        session.startRunning()
    }
    private func startTextDetection() {
        
        let objectRequest = VNDetectRectanglesRequest(completionHandler: self.detectObjectHandler)
       
//        let textRequest = VNDetectTextRectanglesRequest(completionHandler: self.detectTextHandler)
//        textRequest.reportCharacterBoxes = true
        objectRequest.maximumObservations = 4
        objectRequest.minimumConfidence = 0.6
        objectRequest.minimumAspectRatio = 0.3

        self.request = [objectRequest]
    }
    
    private func detectObjectHandler(request:VNRequest, error: Error?) {
        guard let req = request.results else {
            print("no result")
            return
        }
            let result = req.map({ $0 as? VNRectangleObservation})
        
            DispatchQueue.main.async {
                if result.isEmpty {
                    self.cameraButton.setTitle("looking", for: .normal)
                    self.cameraButton.setTitleColor(UIColor.lightGray, for: .normal)
                    self.cameraButton.isEnabled = false
                } else {
                    self.cameraButton.setTitle("Capture", for: .normal)
                    self.cameraButton.setTitleColor(UIColor.blue, for: .normal)
                    self.cameraButton.isEnabled = true
                }
                self.imageView.layer.sublayers?.removeSubrange(1...)
                
                let drawLayer = self.imageView.layer
                self.draw(rectangles: result as! [VNRectangleObservation], onImageWithBounds: drawLayer.bounds)
                drawLayer.setNeedsDisplay()
                   
            }
        
    }
    private func detectTextHandler(request: VNRequest, error: Error?) {
        guard let observation = request.results else {
            print("no result")
            return
        }
        let result = observation.map({$0 as? VNTextObservation})
        
        DispatchQueue.main.async {
            self.imageView.layer.sublayers?.removeSubrange(1...)
            for region in result {
                guard let myRegion = region else {
                    continue
                }
                self.highlightWord(box: myRegion)
                if let boxes = region?.characterBoxes {
                    for characterBox in boxes {
                        self.highlightLetters(box: characterBox)
                    }
                }
            }
        }
    }
  
    private func highlightWord(box: VNTextObservation) {
        guard let boxes = box.characterBoxes else {
            return
        }
        var maxX: CGFloat = 9999.0
        var minX: CGFloat = 0.0
        var maxY: CGFloat = 9999.0
        var minY: CGFloat = 0.0
        
        for char in boxes {
            if char.bottomLeft.x < maxX {
                maxX = char.bottomLeft.x
            }
            if char.bottomRight.x > minX {
                minX = char.bottomRight.x
            }
            if char.bottomRight.y < maxY {
                maxY = char.bottomRight.y
            }
            if char.topRight.y > minY {
                minY = char.topRight.y
            }
        }
    }
    private func highlightLetters(box: VNRectangleObservation) {
        let xCord = box.topLeft.x * imageView.frame.size.width
        let yCord = (1 - box.topLeft.y) * imageView.frame.size.height
        let width = (box.topRight.x - box.bottomLeft.x) * imageView.frame.size.width
        let height = (box.topLeft.y - box.bottomLeft.y) * imageView.frame.size.height
        let outline = CALayer()
        outline.frame = CGRect(x: xCord, y: yCord, width: width, height: height)
        outline.borderWidth = 1.0
        outline.borderColor = UIColor.blue.cgColor
        imageView.layer.addSublayer(outline)
    }
   
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
            var requestOptions: [VNImageOption : Any] = [:]
            
            if let cameraIntrinsicData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
                requestOptions = [.cameraIntrinsics: cameraIntrinsicData]
            }
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: CGImagePropertyOrientation(rawValue: 6)!, options: requestOptions)
                do {
                    try imageRequestHandler.perform(self.request)
                } catch {
                    print(error)
            }
 
    }
}
// MARK: - Helper Method
extension ViewController {
    // Rectangles are RED.
    private func draw(rectangles: [VNRectangleObservation], onImageWithBounds bounds: CGRect) {
        CATransaction.begin()
        for observation in rectangles {
            let rectBox = boundingBox(forRegionOfInterest: observation.boundingBox, withinImageBounds: bounds)
            let rectLayer = shapeLayer(color: .red, frame: rectBox)
            
            // Add to pathLayer on top of image.
            
            self.imageView.layer.addSublayer(rectLayer)
        }
        CATransaction.commit()
    }
    private func boundingBox(forRegionOfInterest: CGRect, withinImageBounds bounds: CGRect) -> CGRect {
        
        let imageWidth = bounds.width
        let imageHeight = bounds.height
        
        // Begin with input rect.
        var rect = forRegionOfInterest
        
        // Reposition origin.
        rect.origin.x *= imageWidth
        rect.origin.x += bounds.origin.x
        rect.origin.y = (1 - rect.origin.y) * imageHeight + bounds.origin.y
        
        // Rescale normalized coordinates.
        rect.size.width *= imageWidth
        rect.size.height *= imageHeight
        
        return rect
    }
    private func shapeLayer(color: UIColor, frame: CGRect) -> CAShapeLayer {
        // Create a new layer.
        let layer = CAShapeLayer()
        
        // Configure layer's appearance.
        layer.fillColor = nil // No fill to show boxed object
        layer.shadowOpacity = 0
        layer.shadowRadius = 0
        layer.borderWidth = 2
        
        // Vary the line color according to input.
        layer.borderColor = color.cgColor
        
        // Locate the layer.
        layer.anchorPoint = .zero
        layer.frame = frame
        layer.masksToBounds = true
        
        // Transform the layer to have same coordinate system as the imageView underneath it.
        layer.transform = CATransform3DMakeScale(1, -1, 1)
        
        return layer
    }
}

extension CGPoint {
    func scaled(to size: CGSize) -> CGPoint {
        return CGPoint(x: self.x * size.width,
                       y: self.y * size.height)
    }
}
