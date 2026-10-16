import 'package:flutter/material.dart';
import 'theme.dart';

/// Reglas de contraseña (las mismas que valida el backend).
class PasswordRules {
  static bool hasLength(String p) => p.length >= 8;
  static bool hasDigit(String p) => RegExp(r'[0-9]').hasMatch(p);
  static bool hasSpecial(String p) =>
      RegExp(r'''[!"#$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~]''').hasMatch(p);

  /// null si es válida; si no, un mensaje con lo que falta.
  static String? error(String p) {
    final falta = <String>[
      if (!hasLength(p)) 'al menos 8 caracteres',
      if (!hasDigit(p)) 'un número',
      if (!hasSpecial(p)) 'un carácter especial',
    ];
    if (falta.isEmpty) return null;
    final lista = falta.length == 1
        ? falta.first
        : '${falta.sublist(0, falta.length - 1).join(', ')} y ${falta.last}';
    return 'La contraseña necesita $lista';
  }
}

/// Lista que se va marcando en verde mientras se escribe la contraseña.
class PasswordChecklist extends StatelessWidget {
  final TextEditingController controller;
  const PasswordChecklist(this.controller, {super.key});

  Widget _row(bool ok, String text) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(children: [
          Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16, color: ok ? AppColors.green : Colors.blueGrey.shade300),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12, color: ok ? AppColors.green : Colors.blueGrey.shade500)),
        ]),
      );

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (_, v, __) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _row(PasswordRules.hasLength(v.text), 'Mínimo 8 caracteres'),
          _row(PasswordRules.hasDigit(v.text), 'Al menos un número'),
          _row(PasswordRules.hasSpecial(v.text), 'Un carácter especial (! @ # % & *)'),
        ]),
      );
}
