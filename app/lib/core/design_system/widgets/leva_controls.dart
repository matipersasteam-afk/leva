import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../leva_tokens.dart';
import '../leva_typography.dart';
import 'leva_primitives.dart';

enum LevaButtonVariant { gold, line, dark }

/// Botón LEVA. El dorado es la acción principal de cada pantalla: una por vista.
class LevaButton extends StatelessWidget {
  const LevaButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = LevaButtonVariant.gold,
    this.icon,
    this.small = false,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final LevaButtonVariant variant;
  final IconData? icon;
  final bool small;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null && !loading;
    final height = small ? 44.0 : 56.0;
    final cut = small ? LevaRadius.chamferSmall : LevaRadius.chamfer;

    final (
      Color fg,
      Gradient? gradient,
      Color? fill,
      Color? border,
    ) = switch (variant) {
      _ when disabled => (
        LevaColors.tx3,
        null,
        LevaColors.ink3,
        LevaColors.line2,
      ),
      LevaButtonVariant.gold => (
        LevaColors.ink1,
        LevaGradients.gold,
        null,
        null,
      ),
      LevaButtonVariant.line => (
        LevaColors.gold200,
        null,
        const Color(0x0AD4AF5A),
        LevaColors.goldLine,
      ),
      LevaButtonVariant.dark => (
        LevaColors.tx1,
        null,
        LevaColors.ink3,
        LevaColors.line,
      ),
    };
    final style = (small ? LevaType.buttonSmall : LevaType.button).copyWith(
      color: fg,
    );

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
            ),
          )
        else if (icon != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(icon, size: 20, color: fg),
          ),
        Flexible(
          child: Text(
            label.toUpperCase(),
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return LevaPressable(
      onTap: loading ? null : onPressed,
      semanticLabel: label,
      haptic: variant == LevaButtonVariant.gold,
      child: SizedBox(
        height: height,
        child: Chamfered(
          cut: cut,
          gradient: gradient,
          color: fill,
          borderColor: border,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: small ? 16 : 24),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Chip de filtro (categorías, días).
class LevaChip extends StatelessWidget {
  const LevaChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LevaPressable(
      onTap: onTap,
      scale: 0.96,
      child: Semantics(
        selected: selected,
        child: AnimatedContainer(
          duration: LevaMotion.fast,
          curve: Curves.ease,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(LevaRadius.sm),
            gradient: selected ? LevaGradients.gold : null,
            border: Border.all(
              color: selected ? LevaColors.gold500 : LevaColors.line2,
            ),
          ),
          // widthFactor 1: el chip mide lo que su texto, también dentro de un Wrap.
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: LevaType.body(
                size: 13,
                weight: selected ? 700 : 500,
                color: selected ? LevaColors.ink1 : LevaColors.tx2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum LevaTagKind { live, ok, pending, gold, mute }

/// Etiqueta de estado: EN VIVO, PAGADO, PENDIENTE…
class LevaTag extends StatelessWidget {
  const LevaTag(this.label, {super.key, this.kind = LevaTagKind.mute});
  final String label;
  final LevaTagKind kind;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color? border) = switch (kind) {
      LevaTagKind.live => (
        const Color(0x24F0484F),
        const Color(0xFFFF8A8F),
        null,
      ),
      LevaTagKind.ok => (
        const Color(0x2143C08F),
        const Color(0xFF7BDDB5),
        null,
      ),
      LevaTagKind.pending => (
        const Color(0x21F09A4A),
        const Color(0xFFFFB877),
        null,
      ),
      LevaTagKind.gold => (
        LevaColors.goldWash,
        LevaColors.gold200,
        LevaColors.goldLine,
      ),
      LevaTagKind.mute => (const Color(0x0FFFFFFF), LevaColors.tx2, null),
    };
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(LevaRadius.xs),
        border: border == null ? null : Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (kind == LevaTagKind.live)
            const Padding(padding: EdgeInsets.only(right: 6), child: LiveDot()),
          Text(label.toUpperCase(), style: LevaType.tag.copyWith(color: fg)),
        ],
      ),
    );
  }
}

/// Punto rojo que late para "en vivo". Quieto si el sistema pide menos movimiento.
class LiveDot extends StatefulWidget {
  const LiveDot({super.key, this.size = 6});
  final double size;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = _c.value;
        final o = 1 - 0.75 * (t < .5 ? t * 2 : (1 - t) * 2);
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: LevaColors.live.withValues(alpha: o),
          ),
        );
      },
    );
  }
}

/// Control segmentado con indicador dorado que se desliza (220 ms, ease-in-out).
class LevaSegmented extends StatelessWidget {
  const LevaSegmented({
    super.key,
    required this.options,
    required this.index,
    required this.onChanged,
  });
  final List<String> options;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final n = options.length;
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: LevaColors.ink2,
        borderRadius: BorderRadius.circular(LevaRadius.sm),
        border: Border.all(color: LevaColors.line),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: LevaMotion.indicator,
            curve: LevaMotion.easeInOut,
            alignment: Alignment(n == 1 ? 0 : -1 + 2 * index / (n - 1), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / n,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LevaGradients.gold,
                  borderRadius: BorderRadius.circular(LevaRadius.xs),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: Semantics(
                    selected: i == index,
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(i),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: LevaMotion.fast,
                          style: LevaType.body(
                            size: 13,
                            weight: 600,
                            color: i == index
                                ? LevaColors.ink1
                                : LevaColors.tx3,
                          ),
                          child: Text(options[i]),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Panel: superficie elevada estándar.
class LevaPanel extends StatelessWidget {
  const LevaPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(LevaSpace.s4),
    this.highlight = false,
  });
  final Widget child;
  final EdgeInsets padding;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: highlight ? LevaGradients.navyCard : LevaGradients.panel,
        borderRadius: BorderRadius.circular(LevaRadius.md),
        border: Border.all(
          color: highlight ? LevaColors.goldLine : LevaColors.line,
        ),
        boxShadow: highlight ? LevaShadows.s2 : LevaShadows.s1,
      ),
      child: child,
    );
  }
}

/// Encabezado de sección en display.
class LevaSectionHeader extends StatelessWidget {
  const LevaSectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: LevaSpace.s8, bottom: LevaSpace.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text(title.toUpperCase(), style: LevaType.m)),
          ?trailing,
        ],
      ),
    );
  }
}

class LevaTabItem {
  const LevaTabItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Barra de pestañas flotante del jugador, con indicador dorado inclinado.
class LevaTabBar extends StatelessWidget {
  const LevaTabBar({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
  });
  final List<LevaTabItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final n = items.length;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(LevaRadius.lg),
        boxShadow: LevaShadows.s2,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LevaRadius.lg),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xEB132037),
              borderRadius: BorderRadius.circular(LevaRadius.lg),
              border: Border.all(color: LevaColors.line),
            ),
            child: _tabs(n),
          ),
        ),
      ),
    );
  }

  Widget _tabs(int n) {
    return Stack(
      children: [
        Row(
          children: [
            for (var i = 0; i < n; i++)
              Expanded(
                child: Semantics(
                  selected: i == index,
                  button: true,
                  label: items[i].label,
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          items[i].icon,
                          size: 20,
                          color: i == index
                              ? LevaColors.gold200
                              : LevaColors.tx3,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          items[i].label.toUpperCase(),
                          style: LevaType.tag.copyWith(
                            color: i == index
                                ? LevaColors.gold200
                                : LevaColors.tx3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        Positioned.fill(
          bottom: 6,
          child: IgnorePointer(
            child: AnimatedAlign(
              duration: LevaMotion.indicator,
              curve: LevaMotion.easeInOut,
              alignment: Alignment(n == 1 ? 0 : -1 + 2 * index / (n - 1), 1),
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                child: const Center(
                  heightFactor: 1,
                  child: LevaSlash(width: 22, height: 3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
