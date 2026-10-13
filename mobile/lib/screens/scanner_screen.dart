import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Abre la cámara y devuelve el código de barras leído (Navigator.pop).
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _done = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Escanear código de barras')),
        body: Stack(children: [
          MobileScanner(
            onDetect: (capture) {
              if (_done) return;
              final code = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
              if (code == null || code.isEmpty) return;
              _done = true;
              Navigator.pop(context, code);
            },
          ),
          Center(
            child: Container(
              width: 280,
              height: 170,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Text('Apunta al código de barras del producto',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ]),
      );
}
