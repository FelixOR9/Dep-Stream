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
///
/// La textura se gira con [rotationDegrees] (0/90/180/270, múltiplo
/// de 90, calculado en Kotlin): `SurfaceTexture` no tiene
/// `setTransform`, así que el giro se aplica aquí, en el widget.
/// El `AspectRatio` va DENTRO del `RotatedBox` para que la textura
/// nunca se distorsione: el giro de 90°/270° la deja más pequeña con
/// barras negras, pero derecha y sin estirar. El overlay no se gira.
class CameraPreviewWidget extends StatelessWidget {
  const CameraPreviewWidget({
    required this.textureId,
    required this.overlay,
    this.rotationDegrees = 0,
    super.key,
  });

  /// Id de la textura de la sesión, o `null` si aún no hay vista previa.
  final int? textureId;

  /// El overlay del partido (marcador, reloj, periodo, estado).
  final Widget overlay;

  /// Grados que hay que girar la textura para que se vea derecha.
  final int rotationDegrees;

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
            RotatedBox(
              quarterTurns: (rotationDegrees ~/ 90) % 4,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Texture(textureId: textureId),
              ),
            ),
          overlay,
        ],
      ),
    );
  }
}
