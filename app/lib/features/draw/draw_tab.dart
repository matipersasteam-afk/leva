import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';
import '../../domain/draw/draw.dart';
import '../../domain/models/event.dart';
import '../../domain/models/registration.dart';
import 'draw_view.dart';

/// Pestaña Cuadro: grupos y llave del torneo, en vivo.
class DrawTab extends ConsumerStatefulWidget {
  const DrawTab({super.key});

  @override
  ConsumerState<DrawTab> createState() => _DrawTabState();
}

class _DrawTabState extends ConsumerState<DrawTab> {
  String? _eventId;
  String? _categoryId;
  int _view = 1; // 0 grupos, 1 llave

  @override
  Widget build(BuildContext context) {
    final events =
        ref.watch(publicEventsProvider).value ?? const <PadelEvent>[];
    final event =
        events.where((e) => e.id == _eventId).firstOrNull ?? events.firstOrNull;
    final categories = event == null
        ? const <EventCategory>[]
        : (ref.watch(categoriesProvider(event.id)).value ??
                  const <EventCategory>[])
              .where((c) => c.isPublishedDraw)
              .toList();
    final mine = event == null
        ? const <Registration>[]
        : ref.watch(myRegistrationsProvider(event.id)).value ??
              const <Registration>[];
    final myCategory = mine
        .where((r) => categories.any((c) => c.id == r.categoryId))
        .firstOrNull
        ?.categoryId;
    final cat =
        categories.where((c) => c.id == _categoryId).firstOrNull ??
        categories.where((c) => c.id == myCategory).firstOrNull ??
        categories.firstOrNull;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 140),
        children: [
          LevaTopBar(
            title: event?.name ?? 'Cuadro',
            trailing: event == null || cat == null
                ? null
                : LevaIconButton(
                    icon: Icons.ios_share,
                    label: 'Copiar link público del cuadro',
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(
                          text:
                              'https://leva-padel-app.web.app/#/c/${event.slug}',
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Link del cuadro copiado'),
                        ),
                      );
                    },
                  ),
          ),
          if (event == null || cat == null)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: LevaSpace.gutter),
              child: LevaEmptyState(
                title: 'Sin cuadro todavía',
                message: 'Cuando se publique el draw de tu torneo, lo vas a ver aquí en vivo.',
              ),
            )
          else ...[
            if (events.length > 1)
              _ChipRow(
                children: [
                  for (final e in events)
                    LevaChip(
                      label: e.name,
                      selected: e.id == event.id,
                      onTap: () => setState(() {
                        _eventId = e.id;
                        _categoryId = null;
                      }),
                    ),
                ],
              ),
            _ChipRow(
              children: [
                for (final c in categories)
                  LevaChip(
                    label: c.name,
                    selected: c.id == cat.id,
                    onTap: () => setState(() => _categoryId = c.id),
                  ),
              ],
            ),
            _CategoryDraw(
              event: event,
              category: cat,
              view: _view,
              onView: (v) => setState(() => _view = v),
              myUid: ref.watch(authStateProvider).value?.uid,
              myRegIds: {for (final r in mine) r.id},
            ),
          ],
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(
      LevaSpace.gutter,
      0,
      LevaSpace.gutter,
      LevaSpace.s3,
    ),
    child: Row(
      children: [
        for (final c in children) ...[c, const SizedBox(width: LevaSpace.s2)],
      ],
    ),
  );
}

class _CategoryDraw extends ConsumerWidget {
  const _CategoryDraw({
    required this.event,
    required this.category,
    required this.view,
    required this.onView,
    required this.myUid,
    required this.myRegIds,
  });

  final PadelEvent event;
  final EventCategory category;
  final int view;
  final ValueChanged<int> onView;
  final String? myUid;
  final Set<String> myRegIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (eventId: event.id, categoryId: category.id);
    final matches = ref.watch(matchesProvider(key)).value ?? const [];
    final groups = ref.watch(groupsProvider(key)).value ?? const [];
    final hasKo = matches.any((m) => m.stage == DrawStage.knockout);
    final hasGroups = groups.isNotEmpty;
    final effectiveView = !hasGroups ? 1 : (!hasKo ? 0 : view);
    final americano = category.format == DrawFormat.americano;
    final qualifiers = (category.format == DrawFormat.relampago) ? 1 : 2;

    final children = <Widget>[
      if (hasGroups && hasKo)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            LevaSpace.gutter,
            0,
            LevaSpace.gutter,
            LevaSpace.s4,
          ),
          child: LevaSegmented(
            options: const ['Grupos', 'Eliminatoria'],
            index: effectiveView,
            onChanged: onView,
          ),
        ),
    ];

    if (effectiveView == 0) {
      for (final g in groups) {
        final ids = [for (final t in g.teams) t.regId ?? t.label];
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LevaSpace.gutter,
              0,
              LevaSpace.gutter,
              LevaSpace.s3,
            ),
            child: GroupTable(
              name: g.name,
              rows: computeStandings(
                ids,
                groupResults(matches, g.name),
                byGames: americano,
              ),
              labels: {for (final t in g.teams) t.regId ?? t.label: t.label},
              qualifiers: qualifiers,
              highlightIds: myRegIds,
              byGames: americano,
            ),
          ),
        );
      }
    } else {
      final b = bracketFromStored(matches, mineUids: {?myUid});
      children.add(LevaBracket(rounds: b.rounds, roundNames: b.names));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
