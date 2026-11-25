import 'package:flutter/material.dart';

/// Vista previa de la cámara en 16:9, con el overlay encima.
///
/// Recibe el id de la textura de la sesión Camera2 y el widget del
/// overlay ya construido. Separado de la pantalla para poder probarlo
/// con una textura falsa.
///
/// Si todavía no hay textura (la cámara se está abriendo o falló),
/// muestra un marcador de posición honesto ("Abriendo cámara…"),
/// nunca una imagen falsa ni un fotograma inventado. El overlay se
/// dibuja igual con o sin textura: el marcador no depende de la cámara.
class CameraPreviewWidget extends StatelessWidget {
  const CameraPreviewWidget({
    required this.textureId,
    required this.overlay,
    super.key,
  });

  /// Id de la textura de la sesión, o `null` si aún no hay vista previa.
  final int? textureId;

  /// El overlay del partido (marcador, reloj, periodo, estado).
  final Widget overlay;

  @override
  Widget build(BuildContext context) {
    final textureId = this.textureId;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (textureId == null)
            Container(
              color: Colors.black,
              child: const Center(
                child: Text(
                  'Abriendo cámara…',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            )
          else
            Texture(textureId: textureId),
          overlay,
        ],
      ),
    );
  }
}
