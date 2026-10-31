import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';
import '../../domain/models/player_profile.dart';

/// Crear (primera vez) o editar el perfil de jugador.
class ProfileFormScreen extends ConsumerStatefulWidget {
  const ProfileFormScreen({super.key, this.editing = false});
  final bool editing;

  @override
  ConsumerState<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends ConsumerState<ProfileFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nick = TextEditingController();
  final _club = TextEditingController();
  PlayerCategory? _category;
  Hand _hand = Hand.diestra;
  CourtPosition _position = CourtPosition.drive;
  bool _busy = false;
  bool _loaded = false;
  String? _error;
  bool _categoryMissing = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authRepositoryProvider).currentUser;
    _name.text = user?.displayName ?? '';
  }

  void _load(PlayerProfile p) {
    if (_loaded) return;
    _loaded = true;
    _name.text = p.displayName;
    _nick.text = p.nickname ?? '';
    _club.text = p.club;
    _category = p.category;
    _hand = p.hand;
    _position = p.position;
  }

  @override
  void dispose() {
    _name.dispose();
    _nick.dispose();
    _club.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final valid = _form.currentState!.validate();
    setState(() => _categoryMissing = _category == null);
    if (!valid || _category == null) return;
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    final current = ref.read(myProfileProvider).value;
    final profile = PlayerProfile(
      uid: user.uid,
      displayName: _name.text,
      nickname: _nick.text,
      category: _category!,
      club: _club.text,
      hand: _hand,
      position: _position,
      photoUrl: current?.photoUrl,
    );
    try {
      final repo = ref.read(profileRepositoryProvider);
      widget.editing && current != null
          ? await repo.update(profile)
          : await repo.create(profile);
      if (mounted && widget.editing) context.pop();
      // Al crear, el router lleva al inicio cuando el perfil aparece.
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No pudimos guardar tu perfil. Revisa tu conexión e intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = ref.watch(myProfileProvider).value;
    if (widget.editing && existing != null) _load(existing);

    return Scaffold(
      body: LevaCourtBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  LevaTopBar(
                    // En el alta el titular "ARMA TU FICHA" ya nombra la pantalla.
                    title: widget.editing ? 'Editar perfil' : null,
                    onBack: widget.editing ? () => context.pop() : null,
                    trailing: widget.editing
                        ? null
                        : LevaIconButton(
                            icon: Icons.logout,
                            label: 'Cerrar sesión',
                            onTap: () =>
                                ref.read(authRepositoryProvider).signOut(),
                          ),
                  ),
                  Expanded(
                    child: Form(
                      key: _form,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          LevaSpace.gutter,
                          0,
                          LevaSpace.gutter,
                          LevaSpace.s10,
                        ),
                        children: [
                          if (!widget.editing) ...[
                            Text('ARMA TU', style: LevaType.xl),
                            GoldText('FICHA', style: LevaType.xl),
                            const SizedBox(height: LevaSpace.s2),
                            Text(
                              'La usamos para inscribirte, sembrarte en el cuadro y avisarte de tus partidos.',
                              style: LevaType.body(
                                size: 14,
                                color: LevaColors.tx2,
                              ),
                            ),
                            const SizedBox(height: LevaSpace.s6),
                          ],
                          LevaField(
                            label: 'Nombre y apellido',
                            controller: _name,
                            hint: 'Julia Gasparini',
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            validator: ProfileValidators.displayName,
                          ),
                          const SizedBox(height: LevaSpace.s4),
                          LevaField(
                            label: 'Apodo (opcional)',
                            controller: _nick,
                            hint: 'Chispita',
                            textInputAction: TextInputAction.next,
                            validator: ProfileValidators.nickname,
                          ),
                          const SizedBox(height: LevaSpace.s4),
                          LevaField(
                            label: 'Club',
                            controller: _club,
                            hint: 'Tu club o "Sin club"',
                            helper: 'Sirve para no cruzarte con parejas de tu club en la primera ronda.',
                            textCapitalization: TextCapitalization.words,
                            validator: ProfileValidators.club,
                          ),
                          const SizedBox(height: LevaSpace.s5),
                          Text('Categoría', style: LevaType.label),
                          const SizedBox(height: LevaSpace.s2),
                          Wrap(
                            spacing: LevaSpace.s2,
                            runSpacing: LevaSpace.s2,
                            children: [
                              for (final c in PlayerCategory.values)
                                LevaChip(
                                  label: c.label,
                                  selected: _category == c,
                                  onTap: () => setState(() {
                                    _category = c;
                                    _categoryMissing = false;
                                  }),
                                ),
                            ],
                          ),
                          if (_categoryMissing)
                            Padding(
                              padding: const EdgeInsets.only(top: LevaSpace.s2),
                              child: Text(
                                'Elige tu categoría.',
                                style: LevaType.body(
                                  size: 12.5,
                                  color: const Color(0xFFFF8A8F),
                                ),
                              ),
                            ),
                          const SizedBox(height: LevaSpace.s5),
                          Text('Mano hábil', style: LevaType.label),
                          const SizedBox(height: LevaSpace.s2),
                          LevaSegmented(
                            options: [for (final h in Hand.values) h.label],
                            index: _hand.index,
                            onChanged: (i) =>
                                setState(() => _hand = Hand.values[i]),
                          ),
                          const SizedBox(height: LevaSpace.s5),
                          Text('Posición', style: LevaType.label),
                          const SizedBox(height: LevaSpace.s2),
                          LevaSegmented(
                            options: [
                              for (final p in CourtPosition.values) p.label,
                            ],
                            index: _position.index,
                            onChanged: (i) => setState(
                              () => _position = CourtPosition.values[i],
                            ),
                          ),
                          const SizedBox(height: LevaSpace.s6),
                          const LevaNotice(
                            'Pronto vas a poder subir tu foto de perfil.',
                            kind: LevaNoticeKind.info,
                          ),
                          const SizedBox(height: LevaSpace.s5),
                          if (_error != null) ...[
                            LevaNotice(_error!),
                            const SizedBox(height: LevaSpace.s4),
                          ],
                          LevaButton(
                            label: widget.editing
                                ? 'Guardar cambios'
                                : 'Listo, entrar',
                            loading: _busy,
                            onPressed: _save,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
