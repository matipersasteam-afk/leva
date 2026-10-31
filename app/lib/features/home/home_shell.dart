import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/design_system.dart';

/// Estructura del jugador: pestañas con su propio historial de navegación.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const _items = [
    LevaTabItem('Inicio', Icons.home_outlined),
    LevaTabItem('Cuadro', Icons.account_tree_outlined),
    LevaTabItem('Horarios', Icons.calendar_today_outlined),
    LevaTabItem('Perfil', Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Sin cancha en Perfil: su hero sólido la cortaría a medias.
          if (shell.currentIndex != 3)
            const Positioned.fill(child: CourtLines(opacity: 0.05)),
          Positioned.fill(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: shell,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 110,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x000A0D14), Color(0xF00A0D14)],
                    stops: [0, .4],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: MediaQuery.paddingOf(context).bottom + 14,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 496),
                child: LevaTabBar(
                  items: _items,
                  index: shell.currentIndex,
                  onChanged: (i) => shell.goBranch(
                    i,
                    initialLocation: i == shell.currentIndex,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
