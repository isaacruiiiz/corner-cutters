import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../common.dart';
import '../widgets/atoms.dart';
import 'dialogs.dart';
import 'more.dart';
import 'sale.dart';

import '../../core/texto.dart';
/// Pendiente hoy: eventos, ofertas y objetivos del día.
class PendingScreen extends ConsumerWidget {
  const PendingScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final todo = g.missions.where((m) => !m.claimed).toList();
    return Screen(
      child: Column(children: [
        BackHeader('Pendiente hoy', sub: '${plural(g.events.length, 'evento', 'eventos')} · ${plural(g.offers.length, 'oferta', 'ofertas')}'),
        Expanded(
          child: Body([
            if (g.events.isEmpty && g.offers.isEmpty)
              const Note('Nada urgente. El mercado está tranquilo. Sospechosamente tranquilo.', icon: Icons.check_circle_outline, kind: NoteKind.ok),
            if (g.events.isNotEmpty) ...[
              SectionHead('Eventos', trail: '${g.events.length}'),
              for (final e in g.events.reversed)
                EventStrip(
                  cap: e.title,
                  text: e.text,
                  color: e.isProblem ? Hc.bad : Hc.ok,
                  onTap: () => showEventDialog(context, g, e),
                  trail: e.amount >= 1
                      ? Text(money(e.isProblem ? -e.amount : e.amount), style: Ht.numS.copyWith(color: e.isProblem ? Hc.bad : Hc.ok))
                      : const Icon(Icons.chevron_right_rounded, color: Hc.mut),
                ),
            ],
            if (g.offers.isNotEmpty) ...[
              SectionHead('Ofertas', trail: '${g.offers.length}'),
              for (final o in g.offers) OfferCard(offer: o, showAddress: true),
            ],
            SectionHead('Objetivos de hoy', trail: '${g.missions.where((m) => m.done).length} de ${g.missions.length}', trailWidget: HsButton('Logros', size: BtnSize.xs, kind: BtnKind.sec, onTap: () => push(context, const ObjectivesScreen()))),
            ListBlock([
                if (todo.isEmpty) const Padding(padding: EdgeInsets.all(14), child: Text('Objetivos cumplidos. Vuelve mañana.', style: TextStyle(color: Hc.mut))),
                for (var i = 0; i < todo.length; i++) MissionRow(m: todo[i], last: i == todo.length - 1),
              ]),
            const SectionHead('Próximo cobro'),
            Li(
              last: true,
              lead: const IconBox(Icons.payments_outlined, color: Hc.ok, solid: true),
              title: 'Rentas del mes',
              sub: 'En ${dur(g.nextRentIn)} · ${g.dateLabel}',
              trail: Text('+${money(g.monthlyRent)}', style: Ht.numS.copyWith(color: Hc.ok)),
            ),
            Text('Sesión tipo: cobrar, atender eventos, lanzar reformas y reinvertir. Patrimonio: ${money(g.netWorth)}.',
                style: Ht.small, textAlign: TextAlign.center),
          ]),
        ),
      ]),
    );
  }
}
