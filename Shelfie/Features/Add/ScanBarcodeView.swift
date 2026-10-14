import AVFoundation
import SwiftUI

struct ScanBarcodeView: View {
    private enum CameraState { case checking, ready, denied, unavailable }

    @State private var camera: CameraState = .checking
    @State private var scanGeneration = 0
    @State private var status = "Point the camera at the barcode on the back of the book."
    @State private var isLookingUp = false
    @State private var found: BookMetadata?
    @State private var manualISBN = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                cameraArea
                Text(status)
                    .font(Theme.Fonts.ui(15))
                    .opacity(0.8)
                if isLookingUp { ProgressView() }

                Divider()
                Text("Or type the ISBN")
                    .font(Theme.Fonts.ui(14).weight(.semibold))
                HStack {
                    TextField("978…", text: $manualISBN)
                        .keyboardType(.numbersAndPunctuation)
                        .font(Theme.Fonts.ui(16))
                        .padding(12)
                        .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.ink.opacity(0.15)))
                    Button("Look up") { submitManual() }
                        .font(Theme.Fonts.ui(16).weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .foregroundStyle(Theme.Colors.cream)
                        .background(Theme.Colors.brick, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(16)
        }
        .foregroundStyle(Theme.Colors.ink)
        .background(Theme.Colors.cream.ignoresSafeArea())
        .navigationTitle("Scan a barcode")
        .navigationBarTitleDisplayMode(.inline)
        .task { await checkCamera() }
        .sheet(item: $found, onDismiss: resumeScanning) { book in
            AddBookSheet(book: book) { }
        }
    }

    @ViewBuilder
    private var cameraArea: some View {
        switch camera {
        case .checking:
            frame { ProgressView() }
        case .ready:
            frame { BarcodeScannerView { handle(isbn: $0) }.id(scanGeneration) }
        case .denied:
            frame {
                VStack(spacing: 10) {
                    Text("Camera access is off for Shelfie.")
                        .font(Theme.Fonts.ui(15))
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                    .foregroundStyle(Theme.Colors.brick)
                }
            }
        case .unavailable:
            frame { Text("No camera on this device.").font(Theme.Fonts.ui(15)) }
        }
    }

    private func frame<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            Theme.Colors.walnut.opacity(0.08)
            content()
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.brick, lineWidth: 3))
    }

    private func checkCamera() async {
        guard AVCaptureDevice.default(for: .video) != nil else {
            camera = .unavailable
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            camera = .ready
        case .notDetermined:
            camera = await AVCaptureDevice.requestAccess(for: .video) ? .ready : .denied
        default:
            camera = .denied
        }
    }

    private func submitManual() {
        guard let isbn = ISBN.normalize(manualISBN) else {
            status = "That doesn't look like a valid ISBN. Check the digits and try again."
            return
        }
        handle(isbn: isbn)
    }

    private func handle(isbn: String) {
        guard !isLookingUp else { return }
        isLookingUp = true
        status = "Looking up \(isbn)…"
        Task {
            defer { isLookingUp = false }
            do {
                if let book = try await BookLookup.live.lookup(isbn: isbn) {
                    status = "Found it."
                    found = book
                } else {
                    status = "No match for \(isbn). Try again, or search by title instead."
                    scanGeneration += 1
                }
            } catch {
                status = "Couldn't reach the book databases. Check your connection and try again."
                scanGeneration += 1
            }
        }
    }

    private func resumeScanning() {
        status = "Point the camera at the barcode on the back of the book."
        manualISBN = ""
        scanGeneration += 1
    }
}
