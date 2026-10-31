import 'package:flutter/material.dart';

import '../../core/design_system/design_system.dart';

/// Pantalla de muestra del design system (Fase 2). Sirve para validar el look
/// contra el prototipo antes de construir módulos. Datos de ejemplo.
class ShowcaseScreen extends StatefulWidget {
  const ShowcaseScreen({super.key});

  @override
  State<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends State<ShowcaseScreen> {
  int _cat = 1;
  int _seg = 1;
  int _tab = 0;
  int _points = 2;
  bool _paying = false;

  static const _cats = ['Todas', '3ra', '4ta', '5ta', '6ta', 'Suma 9'];
  static const _labels = ['0', '15', '30', '40'];

  Future<void> _fakePay() async {
    setState(() => _paying = true);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => _paying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Stack(
            children: [
              ListView(
                padding: EdgeInsets.fromLTRB(
                  LevaSpace.gutter,
                  MediaQuery.paddingOf(context).top + LevaSpace.s6,
                  LevaSpace.gutter,
                  140,
                ),
                children: [
                  _brand(),
                  const LevaSectionHeader('Tipografía'),
                  _type(),
                  const LevaSectionHeader('Color'),
                  _colors(),
                  const LevaSectionHeader('Botones'),
                  LevaButton(label: 'Inscribirme', onPressed: () {}),
                  const SizedBox(height: LevaSpace.s3),
                  LevaButton(
                    label: _paying ? 'Procesando' : r'Pagar $1,400',
                    loading: _paying,
                    onPressed: _fakePay,
                  ),
                  const SizedBox(height: LevaSpace.s3),
                  const LevaButton(label: 'Continuar al pago'),
                  const SizedBox(height: LevaSpace.s3),
                  Row(
                    children: [
                      Expanded(
                        child: LevaButton(
                          label: 'Check-in',
                          icon: Icons.qr_code_2,
                          small: true,
                          variant: LevaButtonVariant.line,
                          onPressed: () {},
                        ),
                      ),
                      const SizedBox(width: LevaSpace.s2),
                      Expanded(
                        child: LevaButton(
                          label: 'Mis horarios',
                          icon: Icons.schedule,
                          small: true,
                          variant: LevaButtonVariant.dark,
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                  const LevaSectionHeader('Filtros y estados'),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < _cats.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: LevaSpace.s2),
                            child: LevaChip(
                              label: _cats[i],
                              selected: _cat == i,
                              onTap: () => setState(() => _cat = i),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: LevaSpace.s4),
                  const Wrap(
                    spacing: LevaSpace.s2,
                    runSpacing: LevaSpace.s2,
                    children: [
                      LevaTag('En vivo', kind: LevaTagKind.live),
                      LevaTag('Pagado', kind: LevaTagKind.ok),
                      LevaTag('Pendiente', kind: LevaTagKind.pending),
                      LevaTag('4ta · Cuartos', kind: LevaTagKind.gold),
                      LevaTag('Semifinal'),
                    ],
                  ),
                  const SizedBox(height: LevaSpace.s4),
                  LevaSegmented(
                    options: const ['Grupos', 'Eliminatoria'],
                    index: _seg,
                    onChanged: (i) => setState(() => _seg = i),
                  ),
                  const LevaSectionHeader('Próximo partido'),
                  NextMatchCard(
                    a: const ['Gasparini', 'De Anda'],
                    b: const ['Lozano', 'Treviño'],
                    captionA: 'Tú y Chispita',
                    captionB: 'Sembrados #5',
                    round: '4ta · Cuartos',
                    court: '3',
                    time: '17:30',
                    countdown: '42 min',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _TransitionDemo(),
                      ),
                    ),
                  ),
                  const LevaSectionHeader('Marcador'),
                  LevaPanel(
                    child: Column(
                      children: [
                        ScoreRow(
                          name: 'Romo / Alcalá',
                          sets: const ['6', '3', '-'],
                          setsWon: const [true],
                          point: _labels[_points % 4],
                          serving: true,
                        ),
                        const Divider(),
                        const ScoreRow(
                          name: 'Ibarra / Villaseñor',
                          sets: ['4', '2', '-'],
                          point: '15',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: LevaSpace.s3),
                  LevaButton(
                    label: 'Punto para Romo / Alcalá',
                    icon: Icons.add,
                    variant: LevaButtonVariant.line,
                    small: true,
                    onPressed: () => setState(() => _points++),
                  ),
                  const LevaSectionHeader('Cuadro'),
                  const BracketMatchTile(
                    caption: 'C1',
                    teamA: 'Romo / Alcalá',
                    teamB: 'Ibarra / Villaseñor',
                    live: true,
                  ),
                  const SizedBox(height: LevaSpace.s3),
                  const BracketMatchTile(
                    caption: '17:30 · C3',
                    teamA: 'Gasparini / De Anda',
                    teamB: 'Lozano / Treviño',
                    mine: true,
                  ),
                  const SizedBox(height: LevaSpace.s3),
                  const BracketMatchTile(
                    caption: 'Finalizado',
                    teamA: 'Castañeda / Orozco',
                    teamB: 'Magaña / Cervantes',
                    scoreA: [6, 6],
                    scoreB: [3, 4],
                    winner: 0,
                  ),
                  const SizedBox(height: LevaSpace.s3),
                  const BracketMatchTile(
                    caption: 'Dom 10:00',
                    teamA: null,
                    teamB: 'Castañeda / Orozco',
                  ),
                  const SizedBox(height: LevaSpace.s6),
                  Text(
                    'Datos y escudo de ejemplo. Toca la tarjeta de partido para ver la transición de pantalla.',
                    style: LevaType.meta,
                  ),
                ],
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: MediaQuery.paddingOf(context).bottom + 16,
                child: LevaTabBar(
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                  items: const [
                    LevaTabItem('Inicio', Icons.home_outlined),
                    LevaTabItem('Cuadro', Icons.account_tree_outlined),
                    LevaTabItem('Horarios', Icons.calendar_today_outlined),
                    LevaTabItem('Perfil', Icons.person_outline),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _brand() {
    return Row(
      children: [
        const LevaShield(size: 56),
        const SizedBox(width: LevaSpace.s4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GoldText('LEVA', style: LevaType.display(56)),
              Text(
                'GENTE · PÁDEL · EXPERIENCIAS',
                style: LevaType.support(size: 11, weight: 300, tracking: 0.28),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _type() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BIENVENIDA', style: LevaType.support(size: 13, weight: 300)),
        GoldText('JULIA', style: LevaType.mega),
        const SizedBox(height: LevaSpace.s3),
        GoldText('¡VAMOS A', style: LevaType.xl),
        Text('ROMPERLA!', style: LevaType.xl),
        const SizedBox(height: LevaSpace.s3),
        GoldText('OTOÑO · ALCALÁ', style: LevaType.l),
        const SizedBox(height: LevaSpace.s3),
        Text('TALENTO | DISCIPLINA | FUTURO', style: LevaType.support()),
        const SizedBox(height: LevaSpace.s3),
        Text(
          'Texto de cuerpo: tu pareja recibe la invitación y la acepta desde su app.',
          style: LevaType.body(),
        ),
        Text('Meta: 4ta · Zapopan Pádel', style: LevaType.meta),
      ],
    );
  }

  Widget _colors() {
    Widget sw(Color c, String n) => Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(LevaRadius.sm),
            border: Border.all(color: LevaColors.line2),
          ),
        ),
        const SizedBox(height: 6),
        Text(n, style: LevaType.meta.copyWith(fontSize: 11)),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 44,
          decoration: BoxDecoration(
            gradient: LevaGradients.gold,
            borderRadius: BorderRadius.circular(LevaRadius.sm),
          ),
        ),
        const SizedBox(height: LevaSpace.s3),
        Wrap(
          spacing: LevaSpace.s3,
          runSpacing: LevaSpace.s3,
          children: [
            sw(LevaColors.ink1, 'ink-1'),
            sw(LevaColors.ink2, 'ink-2'),
            sw(LevaColors.navy, 'navy'),
            sw(LevaColors.gold500, 'gold'),
            sw(LevaColors.tx2, 'tx-2'),
            sw(LevaColors.live, 'live'),
            sw(LevaColors.ok, 'ok'),
            sw(LevaColors.pending, 'pend.'),
          ],
        ),
      ],
    );
  }
}

/// Segunda pantalla mínima para ver la transición de cajón.
class _TransitionDemo extends StatelessWidget {
  const _TransitionDemo();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: CourtLines(opacity: 0.08)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(LevaSpace.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LevaPressable(
                    onTap: () => Navigator.of(context).pop(),
                    semanticLabel: 'Atrás',
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0x0DFFFFFF),
                        border: Border.all(color: LevaColors.line),
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: LevaColors.tx1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const LevaTag('En vivo', kind: LevaTagKind.live),
                  const SizedBox(height: LevaSpace.s4),
                  const LevaDuel(
                    a: ['Romo', 'Alcalá'],
                    b: ['Ibarra', 'Villaseñor'],
                    size: 36,
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
