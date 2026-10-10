import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/database/app_database.dart';
import '../../core/text/normalization.dart';

class MerchantAutocomplete extends ConsumerStatefulWidget {
  const MerchantAutocomplete({
    required this.controller,
    required this.onSelected,
    this.label = 'Comercio',
    super.key,
  });
  final String label;
  final TextEditingController controller;
  final ValueChanged<MerchantRecord> onSelected;

  @override
  ConsumerState<MerchantAutocomplete> createState() =>
      _MerchantAutocompleteState();
}

class _MerchantAutocompleteState extends ConsumerState<MerchantAutocomplete> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final merchants =
        ref.watch(merchantsProvider).value ?? const <MerchantRecord>[];
    final aliases =
        ref.watch(merchantAliasesProvider).value ??
        const <MerchantAliasRecord>[];
    return LayoutBuilder(
      builder: (context, constraints) => RawAutocomplete<MerchantRecord>(
        textEditingController: widget.controller,
        focusNode: _focus,
        displayStringForOption: (merchant) => merchant.name,
        optionsBuilder: (value) {
          final query = normalizeForMatching(value.text);
          if (query.isEmpty) return const <MerchantRecord>[];
          final ids = aliases
              .where((a) => normalizeForMatching(a.alias).contains(query))
              .map((a) => a.merchantId)
              .toSet();
          return merchants.where(
            (m) =>
                ids.contains(m.id) ||
                normalizeForMatching(m.name).contains(query),
          );
        },
        onSelected: widget.onSelected,
        fieldViewBuilder: (context, controller, focus, submit) => TextFormField(
          controller: controller,
          focusNode: focus,
          decoration: InputDecoration(labelText: widget.label),
          onFieldSubmitted: (_) => submit(),
        ),
        optionsViewBuilder: (context, select, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: constraints.maxWidth,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final merchant = options.elementAt(index);
                    return ListTile(
                      title: Text(merchant.name),
                      onTap: () => select(merchant),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
