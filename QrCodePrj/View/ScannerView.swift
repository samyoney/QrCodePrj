//
//  ScannerView.swift
//  QrCodePrj
//
//  Created by SAM on R 6/11/18.
//
import SwiftUI
import AVKit

struct ScannerView: View {
  
  @Environment(\.openURL) private var openURL
  
  @State private var scanning = false
  @State private var session = AVCaptureSession()
  @State private var cameraPermission: Permission = .idle
  
  @State private var qrOutput = AVCaptureMetadataOutput()
  
  @State private var errorMessage = ""
  @State private var showError = false
  
  // Camera QR Output Deletage
  @State private var qrDelegate = QRScannerDelegate()
  
  @State private var code = ""
  
  var body: some View {
    VStack(spacing: 8) {
      Button {
        
      } label: {
        Image(systemName: "xmark")
          .font(.title3)
          .foregroundColor(Color("Blue"))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      
      Text("Place the QR code inside the area")
        .font(.title3)
        .foregroundColor(.black.opacity(0.8))
        .padding(.top, 20)
      
      Text("Scanning will start automatically")
        .font(.callout)
        .foregroundColor(.gray)
      
      GeometryReader { proxy in
        let size = proxy.size
        
        ZStack {
          
          CameraView(frameSize: CGSize(width: size.width, height: size.width), session: $session)
            .scaleEffect(0.97)
          
          ForEach(0...4, id: \.self) { index in
            RoundedRectangle(cornerRadius: 2, style: .circular)
              .trim(from: 0.61, to: 0.64)
              .stroke(Color.theme.main, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
              .rotationEffect(.degrees(90 * Double(index)))
          }
        }
        .frame(width: size.width, height: size.width)

        .overlay(alignment: .top, content: {
          Rectangle()
            .fill(Color("Blue"))
            .frame(height: 2.5)
            .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: scanning ? 15 : -15)
            .offset(y: scanning ? size.width : 0)
        })
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        
      }
      .padding(.horizontal, 45)
      
      Spacer(minLength: 15)
      
      Button {
        if !session.isRunning && cameraPermission == .approved {
          reactivateCamera()
          activateScannerAnimation()
        }
      } label: {
        Image(systemName: "qrcode.viewfinder")
          .font(.largeTitle)
          .foregroundColor(.gray)
      }
      
      Spacer(minLength: 45)
      
    }
    .padding(15)
    .onAppear(perform: checkCameraPermission)
    .alert(errorMessage, isPresented: $showError) {
      if cameraPermission == .denied {
        Button("Settings") {
          if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            openURL(settingsURL)
          }
        }
        
        Button("Cancel", role: .cancel) {
          
        }
      }
    }
    .onChange(of: qrDelegate.scannedCode) { newValue in
      if let scannedCode = newValue {
        code = scannedCode
        
        session.stopRunning()
        
        deActivateScannerAnimation()
        
        qrDelegate.clearScannedCode()
      }
    }
  }
}

private extension ScannerView {
  
  func reactivateCamera() {
    DispatchQueue.global(qos: .background).async {
      session.startRunning()
    }
  }
  
  func activateScannerAnimation() {
    withAnimation(.easeInOut(duration: 0.85).delay(0.1).repeatForever(autoreverses: true)) {
      scanning = true
    }
  }
  
  func deActivateScannerAnimation() {
    withAnimation(.easeInOut(duration: 0.85)) {
      scanning = false
    }
  }
  
  func checkCameraPermission() {
    Task {
      switch AVCaptureDevice.authorizationStatus(for: .video) {
        
      case .notDetermined:
        if await AVCaptureDevice.requestAccess(for: .video) {
          cameraPermission = .approved
          setupCamera()
        } else {
          cameraPermission = .denied
          presentError("Please provide access to camera for scanning qr codes")
        }
        
      case .denied, .restricted:
        cameraPermission = .denied
        presentError("Please provide access to camera for scanning qr codes")
        
      case .authorized:
        cameraPermission = .approved
        if session.inputs.isEmpty {
          setupCamera()
        } else {
          session.startRunning()
        }
        
      @unknown default:
        break
      }
    }
  }
  
  func setupCamera() {
    do {
      guard let device = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first else {
        presentError("Camera is not working!")
        return
      }
      
      let input = try AVCaptureDeviceInput(device: device)
      
      guard session.canAddInput(input), session.canAddOutput(qrOutput) else {
        presentError("Camera is not working!")
        return
      }
      
      session.beginConfiguration()
      session.addInput(input)
      session.addOutput(qrOutput)
      
      qrOutput.metadataObjectTypes = [.qr]
      
      qrOutput.setMetadataObjectsDelegate(qrDelegate, queue: .main)
      
      session.commitConfiguration()
      
      DispatchQueue.global(qos: .background).async {
        session.startRunning()
      }
      activateScannerAnimation()
      
    } catch {
      presentError(error.localizedDescription)
    }
  }
  
  func presentError(_ message: String) {
    errorMessage = message
    showError.toggle()
  }
}

struct ScannerView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
 
