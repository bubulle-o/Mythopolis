import 'package:flutter/material.dart';
import 'package:mythopolis/models/rating_zone.dart';

/// Les options d'une jauge réglables au clic droit.
typedef RatingOptions = ({
  int count,          // nombre d'icônes (1 à 20)
  int value,          // valeur initiale = icônes pleines (0 à count)
  bool showEmpty,     // icônes vides visibles en lecture de fiche
  RatingLayout layout,
  int rowCount,       // nombre de lignes (disposition "plusieurs lignes")
});


//////////////////////////////////////////////////////
//                 WIDGET PRINCIPAL                 //
//////////////////////////////////////////////////////

/// Fenêtre d'options d'une jauge. Retourne les nouvelles options, ou
/// null si annulé.
class RatingOptionsDialog extends StatefulWidget {
  final RatingOptions initial;

  const RatingOptionsDialog({super.key, required this.initial});

  /// Nombre maximal d'icônes dans une jauge.
  static const int maxCount = 20;

  /// Ouvre la fenêtre et attend le résultat.
  static Future<RatingOptions?> show(BuildContext context, RatingOptions initial) {
    return showDialog<RatingOptions>(
      context: context,
      builder: (context) => RatingOptionsDialog(initial: initial),
    );
  }

  @override
  State<RatingOptionsDialog> createState() => _RatingOptionsDialogState();
}

class _RatingOptionsDialogState extends State<RatingOptionsDialog> {

  // Copie modifiable des options (validées seulement avec "Valider")
  late int _count = widget.initial.count;
  late int _value = widget.initial.value;
  late bool _showEmpty = widget.initial.showEmpty;
  late RatingLayout _layout = widget.initial.layout;
  late int _rowCount = widget.initial.rowCount;


  //////////////////////////////////////////////////////
  //                     BUILD                        //
  //////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Options de la jauge'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Nombre d'icônes ──
              _buildCounter(
                label: "Nombre d'icônes",
                value: _count,
                min: 1,
                max: RatingOptionsDialog.maxCount,
                onChanged: (v) => setState(() {
                  _count = v;
                  // La valeur et les lignes ne peuvent pas dépasser le nombre
                  if (_value > _count) _value = _count;
                  if (_rowCount > _count) _rowCount = _count;
                }),
              ),

              // ── Valeur initiale ──
              _buildCounter(
                label: 'Valeur initiale',
                value: _value,
                min: 0,
                max: _count,
                onChanged: (v) => setState(() => _value = v),
              ),

              const Divider(),

              // ── Icônes vides en lecture ──
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Icônes vides visibles en lecture'),
                value: _showEmpty,
                onChanged: (v) => setState(() => _showEmpty = v),
              ),

              const Divider(),

              // ── Disposition ──
              const Text('Disposition'),
              const SizedBox(height: 8),
              SegmentedButton<RatingLayout>(
                segments: const [
                  ButtonSegment(
                    value: RatingLayout.line,
                    icon: Icon(Icons.more_horiz),
                    label: Text('Ligne'),
                  ),
                  ButtonSegment(
                    value: RatingLayout.rows,
                    icon: Icon(Icons.grid_view),
                    label: Text('Lignes'),
                  ),
                  ButtonSegment(
                    value: RatingLayout.circle,
                    icon: Icon(Icons.radio_button_unchecked),
                    label: Text('Cercle'),
                  ),
                ],
                selected: {_layout},
                onSelectionChanged: (set) => setState(() => _layout = set.first),
              ),

              // Nombre de lignes : seulement pour "plusieurs lignes"
              if (_layout == RatingLayout.rows) ...[
                const SizedBox(height: 8),
                _buildCounter(
                  label: 'Nombre de lignes',
                  value: _rowCount.clamp(1, _count),
                  min: 1,
                  max: _count,
                  onChanged: (v) => setState(() => _rowCount = v),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop<RatingOptions>(context, (
            count: _count,
            value: _value,
            showEmpty: _showEmpty,
            layout: _layout,
            rowCount: _rowCount.clamp(1, _count),
          )),
          child: const Text('Valider'),
        ),
      ],
    );
  }

  /// Ligne "libellé   [-] valeur [+]" pour un nombre entier borné.
  Widget _buildCounter({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 32,
          child: Text('$value', textAlign: TextAlign.center),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
