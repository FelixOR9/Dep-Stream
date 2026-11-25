import 'package:dep_stream/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Marca de Dep-Stream: cuadro con las iniciales "DS" y el nombre.
/// Reutilizable para el futuro icono de la app. Diseño propio y simple,
/// sin copiar la marca de ninguna otra app.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(size * 0.25),
          ),
          alignment: Alignment.center,
          child: Text(
            'DS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: size * 0.42,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'Dep-Stream',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
