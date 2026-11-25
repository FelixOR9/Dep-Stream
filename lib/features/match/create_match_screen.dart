import 'package:dep_stream/core/database/app_database.dart';
import 'package:dep_stream/features/match/match_repository.dart';
import 'package:dep_stream/features/match/match_session.dart';
import 'package:flutter/material.dart';

/// Formulario para crear un partido (Etapa 1) o editarlo (solo en
/// borrador).
///
/// Campos: equipo local, equipo visitante, fecha, color de cada equipo,
/// duración del periodo y número de periodos. Guarda en SQLite y vuelve
/// a la lista. Sin marcador, sin reloj, sin jugadores: eso es la
/// pantalla de partido (Etapa 1) y las Etapas 6 en adelante.
class CreateMatchScreen extends StatefulWidget {
  const CreateMatchScreen({required this.database, super.key});

  static const String routeName = '/create-match';

  final AppDatabase database;

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _homeController = TextEditingController();
  final _awayController = TextEditingController();
  DateTime _date = DateTime.now();
  String _homeColor = '#D32F2F';
  String _awayColor = '#1976D2';
  int _periodDurationMinutes = 45;
  int _periodsCount = 2;
  MatchSession? _editing;
  bool _initialized = false;
  bool _saving = false;

  static const List<int> _durations = [10, 20, 25, 30, 40, 45];
  static const List<int> _periodsOptions = [1, 2, 3, 4];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final editing =
        ModalRoute.of(context)?.settings.arguments as MatchSession?;
    if (editing != null && editing.status == MatchStatus.draft) {
      _editing = editing;
      _homeController.text = editing.homeTeam;
      _awayController.text = editing.awayTeam;
      _date = editing.createdAt;
      _homeColor = editing.homeColor;
      _awayColor = editing.awayColor;
      _periodDurationMinutes = editing.periodDurationMinutes;
      _periodsCount = editing.periodsCount;
    }
  }

  @override
  void dispose() {
    _homeController.dispose();
    _awayController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repository = MatchRepository(widget.database);
    try {
      final editing = _editing;
      if (editing != null) {
        final updated = editing.copyWith(
          homeTeam: _homeController.text.trim(),
          awayTeam: _awayController.text.trim(),
          createdAt: _date,
          homeColor: _homeColor,
          awayColor: _awayColor,
          periodDurationMinutes: _periodDurationMinutes,
          periodsCount: _periodsCount,
        );
        final applied = await repository.update(updated);
        if (!applied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'El partido ya no está en borrador y no se puede editar.',
                ),
              ),
            );
          }
          return;
        }
      } else {
        final match = MatchSession.create(
          homeTeam: _homeController.text,
          awayTeam: _awayController.text,
          createdAt: _date,
          homeColor: _homeColor,
          awayColor: _awayColor,
          periodDurationMinutes: _periodDurationMinutes,
          periodsCount: _periodsCount,
        );
        await repository.insert(match);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar el partido: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _editing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Editar partido' : 'Crear partido')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _homeController,
              decoration: const InputDecoration(labelText: 'Equipo local'),
              textCapitalization: TextCapitalization.words,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Escribe el equipo local'
                  : null,
            ),
            const SizedBox(height: 16),
            _ColorPicker(
              label: 'Color local',
              selected: _homeColor,
              onSelected: (color) => setState(() => _homeColor = color),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _awayController,
              decoration: const InputDecoration(labelText: 'Equipo visitante'),
              textCapitalization: TextCapitalization.words,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Escribe el equipo visitante'
                  : null,
            ),
            const SizedBox(height: 16),
            _ColorPicker(
              label: 'Color visitante',
              selected: _awayColor,
              onSelected: (color) => setState(() => _awayColor = color),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha del partido'),
              subtitle: Text(_formatDate(_date)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _periodDurationMinutes,
              decoration: const InputDecoration(
                labelText: 'Duración de cada periodo',
              ),
              items: _durations
                  .map(
                    (minutes) => DropdownMenuItem(
                      value: minutes,
                      child: Text('$minutes minutos'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _periodDurationMinutes = value);
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _periodsCount,
              decoration: const InputDecoration(
                labelText: 'Número de periodos',
              ),
              items: _periodsOptions
                  .map(
                    (count) => DropdownMenuItem(
                      value: count,
                      child: Text('$count'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _periodsCount = value);
                }
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : Text(isEditing ? 'Guardar cambios' : 'Guardar partido'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paleta propia de 8 colores (sin paquetes): un círculo grande por
/// color, con borde cuando está elegido.
class _ColorPicker extends StatelessWidget {
  const _ColorPicker({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: MatchSession.teamColors.map((hex) {
            final isSelected = hex == selected;
            return GestureDetector(
              onTap: () => onSelected(hex),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Color(MatchSession.colorValue(hex)),
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 3)
                      : Border.all(color: Colors.grey, width: 1),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
