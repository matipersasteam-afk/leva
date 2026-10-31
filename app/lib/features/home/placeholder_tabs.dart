import 'package:flutter/material.dart';

import '../../core/design_system/design_system.dart';

class ScheduleTab extends StatelessWidget {
  const ScheduleTab({super.key});

  @override
  Widget build(BuildContext context) => _TabPlaceholder(
    title: 'Horarios',
    empty: const LevaEmptyState(
      title: 'Sin partidos programados',
      message:
          'Tus horarios y canchas aparecen aquí cuando el torneo arranque.',
    ),
  );
}

class _TabPlaceholder extends StatelessWidget {
  const _TabPlaceholder({required this.title, required this.empty});
  final String title;
  final Widget empty;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 140),
        children: [
          LevaTopBar(title: title),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: LevaSpace.gutter),
            child: empty,
          ),
        ],
      ),
    );
  }
}
