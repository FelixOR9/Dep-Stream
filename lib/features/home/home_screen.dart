import 'package:dep_stream/core/brand/brand_mark.dart';
import 'package:dep_stream/core/database/app_database.dart';
import 'package:dep_stream/features/match/create_match_screen.dart';
import 'package:dep_stream/features/match/match_repository.dart';
import 'package:dep_stream/features/match/match_session.dart';
import 'package:dep_stream/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';

/// Pantalla principal: lista de partidos guardados.
///
/// Vacía al inicio, con un mensaje honesto. Cada partido muestra sus
/// equipos, su fecha y su estado. No hay botones de funciones que no
/// existen: solo crear un partido y abrir los ajustes.
class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.database, super.key});

  final AppDatabase database;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final MatchRepository _repository;
  late Future<List<MatchSession>> _matchesFuture;

  @override
  void initState() {
    super.initState();
    _repository = MatchRepository(widget.database);
    _loadMatches();
  }

  void _loadMatches() {
    _matchesFuture = _repository.getAll();
  }

  Future<void> _openCreateMatch() async {
    final created = await Navigator.pushNamed<bool>(
      context,
      CreateMatchScreen.routeName,
    );
    if (created == true && mounted) {
      setState(_loadMatches);
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandMark(),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Ajustes',
            onPressed: () =>
                Navigator.pushNamed(context, SettingsScreen.routeName),
          ),
        ],
      ),
      body: FutureBuilder<List<MatchSession>>(
        future: _matchesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudieron cargar los partidos: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final matches = snapshot.data ?? [];
          if (matches.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aún no hay partidos.\nCrea el primero con el botón +.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final match = matches[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(
                    match.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(_formatDate(match.createdAt)),
                  trailing: Chip(label: Text(match.status.label)),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateMatch,
        icon: const Icon(Icons.add),
        label: const Text('Crear partido'),
      ),
    );
  }
}
