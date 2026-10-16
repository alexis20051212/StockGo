import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Ventana con la mascota asomada sobre su borde superior.
/// Se usa igual que un AlertDialog: title, content y actions.
class PeekingDialog extends StatelessWidget {
  final Widget title;
  final Widget content;
  final List<Widget> actions;
  const PeekingDialog({super.key, required this.title, required this.content, required this.actions});

  // Proporciones de assets/mascota/asomada.png (640 x 389)
  static const _ratio = 389 / 640; // alto / ancho
  static const _line = 0.8933; // fracción de la imagen donde apoya las manos

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final cardW = (screenW - 40).clamp(0.0, 440.0).toDouble();
    final monsterW = cardW - 56; // cabe entre las esquinas redondeadas
    final monsterH = monsterW * _ratio;
    final above = monsterH * _line; // parte que sobresale de la tarjeta
    final handsIn = monsterH - above; // manos que caen sobre la tarjeta
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.fromLTRB(20, above + 28, 20, 20),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: cardW,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            padding: EdgeInsets.fromLTRB(24, handsIn + 12, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle.merge(
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.navy),
                  child: title,
                ),
                const SizedBox(height: 14),
                Flexible(child: content),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
              ],
            ),
          ),
          Positioned(
            top: -above,
            child: IgnorePointer(
              // La mascota "sube" desde el borde al abrir la ventana
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 550),
                curve: Curves.easeOutBack,
                builder: (_, t, child) =>
                    Transform.scale(scale: t, alignment: Alignment(0, _line * 2 - 1), child: child),
                child: Image.asset('assets/mascota/asomada.png', width: monsterW),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
