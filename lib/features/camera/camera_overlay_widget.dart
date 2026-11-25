import 'package:dep_stream/features/camera/camera_overlay_data.dart';
import 'package:dep_stream/features/match/match_session.dart';
import 'package:flutter/material.dart';

/// El overlay del partido, dibujado encima de la vista previa.
///
/// Un solo diseño fijo (decisión de Félix): barra superior con equipos
/// y marcador, reloj con periodo y estado debajo, franja de
/// patrocinadores abajo con el texto "Dep-Stream" (sin logos; son
/// Etapa 6). Las plantillas editables llegan en la Etapa 6.
///
/// Los tamaños son proporcionales al ancho del lienzo 16:9 (base
/// 1280): a 1280 de ancho el marcador mide 64 px y el reloj 48 px,
/// como pide el plan; en pantallas más pequeñas todo escala igual,
/// sin recortarse ni estirarse.
class CameraOverlayWidget extends StatelessWidget {
  const CameraOverlayWidget({required this.data, super.key});

  final CameraOverlayData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = (constraints.maxWidth / 1280).clamp(0.1, 2.0);
        return Column(
          children: [
            // Barra superior: equipos con su color y el marcador.
            Container(
              color: Colors.black54,
              padding: EdgeInsets.symmetric(
                horizontal: 24 * scale,
                vertical: 12 * scale,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TeamLabel(
                      name: data.homeTeam,
                      colorHex: data.homeColor,
                      scale: scale,
                      alignRight: true,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                    child: Text(
                      data.scoreText,
                      style: TextStyle(
                        fontSize: 64 * scale,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _TeamLabel(
                      name: data.awayTeam,
                      colorHex: data.awayColor,
                      scale: scale,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12 * scale),
            // Reloj + periodo + estado, centrados.
            Text(
              data.clockText,
              style: TextStyle(
                fontSize: 48 * scale,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: const [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
            Text(
              data.periodLabel,
              style: TextStyle(
                fontSize: 28 * scale,
                color: Colors.white,
                shadows: const [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
            SizedBox(height: 6 * scale),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12 * scale,
                vertical: 4 * scale,
              ),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4 * scale),
              ),
              child: Text(
                data.statusLabel,
                style: TextStyle(
                  fontSize: 24 * scale,
                  color: Colors.white,
                ),
              ),
            ),
            const Spacer(),
            // Franja de patrocinadores: solo el hueco, con "Dep-Stream".
            Container(
              width: double.infinity,
              color: Colors.black45,
              padding: EdgeInsets.symmetric(vertical: 8 * scale),
              child: Text(
                'Dep-Stream',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20 * scale,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TeamLabel extends StatelessWidget {
  const _TeamLabel({
    required this.name,
    required this.colorHex,
    required this.scale,
    this.alignRight = false,
  });

  final String name;
  final String colorHex;
  final double scale;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 20 * scale,
      height: 20 * scale,
      decoration: BoxDecoration(
        color: Color(MatchSession.colorValue(colorHex)),
        shape: BoxShape.circle,
      ),
    );
    final label = Flexible(
      child: Text(
        name,
        style: TextStyle(
          fontSize: 28 * scale,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
    return Row(
      mainAxisAlignment:
          alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: alignRight
          ? [label, SizedBox(width: 8 * scale), dot]
          : [dot, SizedBox(width: 8 * scale), label],
    );
  }
}
