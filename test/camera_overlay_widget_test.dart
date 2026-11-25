import 'package:dep_stream/features/camera/camera_overlay_data.dart';
import 'package:dep_stream/features/camera/camera_overlay_widget.dart';
import 'package:dep_stream/features/camera/camera_preview_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const data = CameraOverlayData(
    homeTeam: 'Águilas',
    awayTeam: 'Leones',
    homeColor: '#D32F2F',
    awayColor: '#1976D2',
    homeScore: 2,
    awayScore: 1,
    clockText: '23:41',
    periodLabel: '2º tiempo',
    statusLabel: 'En vivo',
  );

  Widget overlayAtFullSize() {
    return const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 1280,
          height: 720,
          child: CameraOverlayWidget(data: data),
        ),
      ),
    );
  }

  group('CameraOverlayWidget', () {
    testWidgets('muestra 2-1, 23:41, equipos y 2º tiempo', (tester) async {
      await tester.pumpWidget(overlayAtFullSize());
      await tester.pumpAndSettle();

      expect(find.text('Águilas'), findsOneWidget);
      expect(find.text('Leones'), findsOneWidget);
      expect(find.text('2 - 1'), findsOneWidget);
      expect(find.text('23:41'), findsOneWidget);
      expect(find.text('2º tiempo'), findsOneWidget);
      expect(find.text('En vivo'), findsOneWidget);
    });

    testWidgets('en pausa muestra Pausa', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1280,
              height: 720,
              child: CameraOverlayWidget(
                data: CameraOverlayData(
                  homeTeam: 'Águilas',
                  awayTeam: 'Leones',
                  homeColor: '#D32F2F',
                  awayColor: '#1976D2',
                  homeScore: 0,
                  awayScore: 0,
                  clockText: '10:00',
                  periodLabel: '1er tiempo',
                  statusLabel: 'Pausa',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pausa'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
    });

    testWidgets('la franja de patrocinadores muestra Dep-Stream',
        (tester) async {
      await tester.pumpWidget(overlayAtFullSize());
      await tester.pumpAndSettle();

      expect(find.text('Dep-Stream'), findsOneWidget);
    });
  });

  group('CameraPreviewWidget', () {
    testWidgets('sin textura muestra el marcador honesto, no una imagen falsa',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CameraPreviewWidget(
              textureId: null,
              overlay: Text('overlay'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Abriendo cámara…'), findsOneWidget);
      expect(find.text('overlay'), findsOneWidget);
      expect(find.byType(Texture), findsNothing);
    });

    testWidgets('con textura muestra el Texture y el overlay', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CameraPreviewWidget(
              textureId: 7,
              overlay: Text('overlay'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Texture), findsOneWidget);
      expect(find.text('overlay'), findsOneWidget);
      expect(find.text('Abriendo cámara…'), findsNothing);
    });
  });
}
