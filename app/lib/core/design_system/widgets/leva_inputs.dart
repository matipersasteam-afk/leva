import 'package:flutter/material.dart';

import '../leva_tokens.dart';
import '../leva_typography.dart';
import 'leva_controls.dart';
import 'leva_primitives.dart';

/// Interruptor LEVA: pista dorada cuando está activo.
class LevaSwitch extends StatelessWidget {
  const LevaSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: SizedBox(
          width: 56,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: LevaMotion.base,
              curve: Curves.ease,
              width: 50,
              height: 30,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: value ? LevaGradients.gold : null,
                color: value ? null : const Color(0x1FFFFFFF),
              ),
              child: AnimatedAlign(
                duration: LevaMotion.base,
                curve: LevaMotion.easeOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: LevaColors.tx1,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila de opción con título, detalle y un control a la derecha.
class LevaOptionRow extends StatelessWidget {
  const LevaOptionRow({
    super.key,
    required this.title,
    this.detail,
    required this.trailing,
  });
  final String title;
  final String? detail;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LevaColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: LevaType.body(size: 14.5, weight: 600)),
                if (detail != null)
                  Text(detail!, style: LevaType.meta.copyWith(fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: LevaSpace.s3),
          trailing,
        ],
      ),
    );
  }
}

/// Contador con − y + (canchas, cupos).
class LevaStepper extends StatelessWidget {
  const LevaStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
    this.step = 1,
    this.label,
  });
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final String? label;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, int delta, String tip) {
      final next = value + delta;
      final enabled = next >= min && next <= max;
      return LevaPressable(
        onTap: enabled ? () => onChanged(next) : null,
        scale: 0.9,
        semanticLabel: tip,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 20,
            color: enabled ? LevaColors.gold200 : LevaColors.tx3,
          ),
        ),
      );
    }

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: LevaColors.ink2,
        borderRadius: BorderRadius.circular(LevaRadius.sm),
        border: Border.all(color: LevaColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.remove, -step, 'Restar'),
          SizedBox(
            width: 56,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: LevaType.numbers(26),
              semanticsLabel: label == null ? '$value' : '$label: $value',
            ),
          ),
          btn(Icons.add, step, 'Sumar'),
        ],
      ),
    );
  }
}

/// Tarjeta seleccionable (categoría, método de pago).
class LevaChoiceCard extends StatelessWidget {
  const LevaChoiceCard({
    super.key,
    required this.selected,
    required this.child,
    this.onTap,
    this.enabled = true,
  });
  final bool selected;
  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return LevaPressable(
      onTap: enabled ? onTap : null,
      scale: 0.985,
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: AnimatedOpacity(
          duration: LevaMotion.fast,
          opacity: enabled ? 1 : 0.5,
          child: AnimatedContainer(
            duration: LevaMotion.fast,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(LevaRadius.sm),
              color: selected ? null : LevaColors.ink2,
              gradient: selected
                  ? const LinearGradient(
                      colors: [Color(0x1FD4AF5A), Color(0x05D4AF5A)],
                    )
                  : null,
              border: Border.all(
                color: selected ? LevaColors.gold500 : LevaColors.line,
              ),
            ),
            child: Row(
              children: [
                Expanded(child: child),
                const SizedBox(width: LevaSpace.s3),
                _Radio(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: LevaMotion.fast,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? LevaColors.gold500 : LevaColors.line2,
          width: 1.5,
        ),
      ),
      child: Center(
        child: AnimatedScale(
          duration: LevaMotion.fast,
          curve: LevaMotion.easeOut,
          scale: selected ? 1 : 0.4,
          child: AnimatedOpacity(
            duration: LevaMotion.fast,
            opacity: selected ? 1 : 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LevaGradients.gold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra de pasos (Pareja · Disponibilidad · Pago).
class LevaSteps extends StatelessWidget {
  const LevaSteps({super.key, required this.total, required this.done});
  final int total;
  final int done;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Paso $done de $total',
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: LevaMotion.base,
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: i < done ? LevaGradients.gold : null,
                  color: i < done ? null : const Color(0x1AFFFFFF),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Barra de acción fija abajo con fundido del fondo.
class LevaStickyBar extends StatelessWidget {
  const LevaStickyBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        LevaSpace.gutter,
        28,
        LevaSpace.gutter,
        MediaQuery.paddingOf(context).bottom + LevaSpace.s4,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x000A0D14), LevaColors.ink1],
          stops: [0, .2],
        ),
      ),
      child: child,
    );
  }
}

/// Campo de fecha: se ve como un input (no como botón de acción).
class LevaDateField extends StatelessWidget {
  const LevaDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LevaSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: LevaType.label),
          const SizedBox(height: LevaSpace.s2),
          LevaPressable(
            onTap: onTap,
            scale: 0.99,
            semanticLabel: '$label: $value',
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: LevaColors.ink2,
                borderRadius: BorderRadius.circular(LevaRadius.sm),
                border: Border.all(color: LevaColors.line2),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(value, style: LevaType.body(size: 16))),
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: LevaColors.tx3,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Distintivo de rol en la barra superior.
class LevaRoleChip extends StatelessWidget {
  const LevaRoleChip(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => LevaTag(label, kind: LevaTagKind.gold);
}
