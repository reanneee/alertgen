import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatelessWidget {
  final List<String> allergens;
  final void Function(String barcodeText) onScanResult;

  const BarcodeScannerScreen({
    required this.allergens,
    required this.onScanResult,
  });

  @override
  Widget build(BuildContext context) {
    final MobileScannerController cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );

    return Scaffold(
      appBar: AppBar(title: Text('Scan Barcode')),
      body: MobileScanner(
        controller: cameraController,
        onDetect: (capture) {
          final barcode = capture.barcodes.first;
          final barcodeText = barcode.rawValue ?? '';

          if (barcodeText.isNotEmpty) {
            onScanResult(barcodeText);
            Navigator.pop(context); // Go back to main screen
          }
        },
      ),
    );
  }
}
