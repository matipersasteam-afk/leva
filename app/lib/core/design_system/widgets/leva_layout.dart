import 'package:flutter/material.dart';

import '../leva_tokens.dart';
import '../leva_typography.dart';
import 'leva_primitives.dart';

/// Fondo con las líneas de cancha muy tenues, para pantallas de formulario.
class LevaCourtBackground extends StatelessWidget {
  const LevaCourtBackground({
    super.key,
    required this.child,
    this.opacity = 0.05,
  });
  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(child: CourtLines(opacity: opacity)),
      Positioned.fill(child: child),
    ],
  );
}

/// Botón redondo de ícono (atrás, compartir, editar). 44 px de área táctil.
class LevaIconButton extends StatelessWidget {
  const LevaIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LevaPressable(
      onTap: onTap,
      scale: 0.92,
      semanticLabel: label,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x0DFFFFFF),
          border: Border.all(color: LevaColors.line),
        ),
        child: Icon(icon, size: 20, color: LevaColors.tx1),
      ),
    );
  }
}

/// Barra superior: botón atrás opcional, título en línea de apoyo, acción opcional.
class LevaTopBar extends StatelessWidget {
  const LevaTopBar({
    super.key,
    this.title,
    this.onBack,
    this.trailing,
    this.leading,
  });
  final String? title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LevaSpace.s4,
        LevaSpace.s2,
        LevaSpace.s4,
        LevaSpace.s3,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child:
                leading ??
                (onBack == null
                    ? null
                    : LevaIconButton(
                        icon: Icons.chevron_left,
                        label: 'Atrás',
                        onTap: onBack,
                      )),
          ),
          Expanded(
            child: Text(
              (title ?? '').toUpperCase(),
              textAlign: TextAlign.center,
              style: LevaType.support(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Mínimo 44 (botón de ícono); crece si la acción es más ancha (etiqueta).
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44),
            child: Align(
              alignment: Alignment.centerRight,
              widthFactor: 1,
              child: trailing,
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de formulario con etiqueta visible arriba y error debajo.
class LevaField extends StatelessWidget {
  const LevaField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.validator,
    this.keyboardType,
    this.obscure = false,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.helper,
    this.textCapitalization = TextCapitalization.none,
    this.suffix,
    this.onChanged,
  });

  final ValueChanged<String>? onChanged;

  /// Acción dentro del campo (p. ej. mostrar/ocultar contraseña).
  final Widget? suffix;

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final bool obscure;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: LevaType.label),
        const SizedBox(height: LevaSpace.s2),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscure,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          onFieldSubmitted: onSubmitted,
          onChanged: onChanged,
          textCapitalization: textCapitalization,
          style: LevaType.body(size: 16),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffix,
            helperText: helper,
            helperMaxLines: 3,
            errorMaxLines: 3,
            helperStyle: LevaType.meta.copyWith(fontSize: 12),
            errorStyle: LevaType.body(
              size: 12.5,
              color: const Color(0xFFFF8A8F),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(LevaRadius.sm),
              borderSide: const BorderSide(color: LevaColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(LevaRadius.sm),
              borderSide: const BorderSide(
                color: LevaColors.danger,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum LevaNoticeKind { error, info }

/// Aviso en línea (error de login, información).
class LevaNotice extends StatelessWidget {
  const LevaNotice(this.message, {super.key, this.kind = LevaNoticeKind.error});
  final String message;
  final LevaNoticeKind kind;

  @override
  Widget build(BuildContext context) {
    final error = kind == LevaNoticeKind.error;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(LevaSpace.s3),
        decoration: BoxDecoration(
          // Opaco: el fondo de cancha no se transparenta.
          color: error ? const Color(0xFF221419) : LevaColors.ink2,
          borderRadius: BorderRadius.circular(LevaRadius.sm),
          border: Border.all(
            color: error ? const Color(0x59F0484F) : LevaColors.line,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              error ? Icons.error_outline : Icons.info_outline,
              size: 18,
              color: error ? LevaColors.danger : LevaColors.tx2,
            ),
            const SizedBox(width: LevaSpace.s2),
            Expanded(
              child: Text(
                message,
                style: LevaType.body(size: 13.5, color: LevaColors.tx1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado vacío: título en display + explicación + acción opcional.
class LevaEmptyState extends StatelessWidget {
  const LevaEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
  });
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LevaSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LevaSlash(width: 14, height: 40),
          const SizedBox(height: LevaSpace.s4),
          Text(title.toUpperCase(), style: LevaType.l),
          const SizedBox(height: LevaSpace.s2),
          Text(message, style: LevaType.body(color: LevaColors.tx2)),
          if (action != null) ...[
            const SizedBox(height: LevaSpace.s5),
            action!,
          ],
        ],
      ),
    );
  }
}
