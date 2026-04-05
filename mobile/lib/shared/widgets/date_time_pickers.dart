import 'package:flutter/material.dart';

/// Muestra un campo que abre el selector de fecha nativo de Flutter.
/// [value] es DateTime? mutable; [onChanged] devuelve el nuevo DateTime.
class DatePickerField extends StatelessWidget {
  final DateTime? value;
  final String label;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const DatePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    final display = value != null
        ? '${value!.year.toString().padLeft(4, '0')}-'
            '${value!.month.toString().padLeft(2, '0')}-'
            '${value!.day.toString().padLeft(2, '0')}'
        : '';

    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: firstDate ?? DateTime(2000),
          lastDate: lastDate ?? DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                ),
              const Icon(Icons.calendar_today_outlined, size: 20),
              const SizedBox(width: 8),
            ],
          ),
        ),
        child: Text(display.isEmpty ? '' : display),
      ),
    );
  }
}

/// Selector de fecha + hora (primero calendario, luego reloj).
class DateTimePickerField extends StatelessWidget {
  final DateTime? value;
  final String label;
  final ValueChanged<DateTime?> onChanged;

  const DateTimePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  String _format(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (date == null || !context.mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: value != null
              ? TimeOfDay(hour: value!.hour, minute: value!.minute)
              : TimeOfDay.now(),
        );
        if (time == null) return;
        onChanged(DateTime(
            date.year, date.month, date.day, time.hour, time.minute));
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                ),
              const Icon(Icons.event_outlined, size: 20),
              const SizedBox(width: 8),
            ],
          ),
        ),
        child: Text(value != null ? _format(value!) : ''),
      ),
    );
  }
}

/// Selector de hora (solo hora, sin fecha).
class TimePickerField extends StatelessWidget {
  final TimeOfDay? value;
  final String label;
  final ValueChanged<TimeOfDay?> onChanged;

  const TimePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value ?? TimeOfDay.now(),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.access_time_outlined, size: 20),
          ),
        ),
        child: Text(value != null ? _format(value!) : ''),
      ),
    );
  }
}
