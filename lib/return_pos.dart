import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'extensions.dart';
import 'store.dart';

// POS-style returns use the ORIGINAL invoice line ID, rather than just a SKU.
// This preserves the original rate, selected sale unit and conversion factor.
class _ReturnDraft {
  final int lineId;
  final String product;
  final String variation;
  final String unit;
  final double original;
  final double previouslyReturned;
  final double rate;
  final TextEditingController quantity;
  _ReturnDraft(Map<String, Object?> row, double initial)
      : lineId = row['line_id'] as int,
        product = '${row['product']}',
        variation = ('${row['attributes'] ?? ''}'.trim().isNotEmpty)
            ? '${row['attributes']}  •  ${row['sku']}'
            : '${row['sku']}',
        unit = '${row['unit']}',
        original = numVal(row['original_qty']),
        previouslyReturned = numVal(row['previous_returned']),
        rate = rupees(row['rate']),
        quantity = TextEditingController(text: initial > 0 ? _fmt(initial) : '0');
  double get maxReturn => (original - previouslyReturned).clamp(0, double.infinity).toDouble();
  double get selected => double.tryParse(quantity.text) ?? 0;
  double get lineTotal => selected * rate;
  void dispose() => quantity.dispose();
}

String _fmt(double n) => n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');

class ReturnPosDialog extends StatefulWidget {
  final String kind; // sale or purchase
  final Map<String, Object?>? existing;
  const ReturnPosDialog({super.key, required this.kind, this.existing});
  @override
  State<ReturnPosDialog> createState() => _ReturnPosDialogState();
}

class _ReturnPosDialogState extends State<ReturnPosDialog> {
  final s = Store.instance;
  final search = TextEditingController();
  final reason = TextEditingController(text: 'Return');
  final refund = TextEditingController(text: '0.00');
  final returnDate = TextEditingController(text: nowDate());
  List<Map<String, Object?>> invoices = [];
  List<_ReturnDraft> lines = [];
  List<Map<String, Object?>> paymentAccounts = [];
  int? documentId;
  int? accountId;
  bool loading = true;
  bool saving = false;
  String? error;

  bool get editing => widget.existing != null;
  bool get sale => widget.kind == 'sale';
  double get total => lines.fold(0, (double sum, _ReturnDraft row) => sum + row.lineTotal);
  int get selectedCount => lines.where((r) => r.selected > 0).length;
  bool get walkIn => invoices.where((e) => e['id'] == documentId).any((e) => e['party_id'] == null);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final docs = await s.read('''SELECT d.id,d.invoice,d.date,d.party_id,
        coalesce(p.name,'Walk-in') AS party FROM documents d
        LEFT JOIN parties p ON p.id=d.party_id
        WHERE d.status='POSTED' AND d.kind=? ORDER BY d.id DESC LIMIT 500''', [widget.kind]);
      final accounts = await s.read('''SELECT a.id,a.name,a.code,
        coalesce(pa.holder_name,'') AS holder FROM accounts a
        JOIN payment_accounts pa ON pa.account_id=a.id
        WHERE a.active=1 ORDER BY a.name''');
      if (accounts.isEmpty) throw const FormatException('Add a cash/bank/wallet account first.');
      if (docs.isEmpty) throw const FormatException('No posted invoices found for returns.');
      if (!mounted) return;
      setState(() {
        invoices = docs;
        paymentAccounts = accounts;
        documentId = widget.existing?['document_id'] as int?;
        accountId = widget.existing?['account_id'] as int? ?? accounts.first['id'] as int;
        reason.text = editing ? '${widget.existing!['reason']}' : 'Return';
        refund.text = editing ? rupees(widget.existing!['refunded']).toStringAsFixed(2) : '0.00';
        returnDate.text = editing ? '${widget.existing!['date']}' : nowDate();
        loading = false;
      });
      if (documentId != null) await _loadLines(documentId!);
    } catch (e) {
      if (mounted) setState(() { error = '$e'; loading = false; });
    }
  }

  Future<void> _loadLines(int id) async {
    setState(() { loading = true; error = null; });
    try {
      final currentReturnId = widget.existing?['id'];
      final data = await s.read('''SELECT l.id AS line_id,p.name AS product,v.sku,
        coalesce((SELECT group_concat(a.name || ': ' || vv.value, ', ')
          FROM variant_values vv JOIN attributes a ON a.id=vv.attribute_id
          WHERE vv.variant_id=v.id),'') AS attributes,
        l.qty AS original_qty,l.rate,
        coalesce(u.unit,v.unit) AS unit,
        coalesce((SELECT sum(rl.qty) FROM return_lines rl
          JOIN document_returns dr ON dr.id=rl.return_id
          WHERE rl.source_line_id=l.id AND dr.status='POSTED'
          AND (? IS NULL OR dr.id<>?)),0) AS previous_returned
        FROM document_lines l JOIN variants v ON v.id=l.variant_id
        JOIN products p ON p.id=v.product_id
        LEFT JOIN document_line_units u ON u.line_id=l.id
        WHERE l.document_id=? AND l.is_current=1 ORDER BY l.id''',
        [currentReturnId, currentReturnId, id]);
      final previous = editing
          ? await s.read('SELECT source_line_id,qty FROM return_lines WHERE return_id=?', [currentReturnId])
          : <Map<String, Object?>>[];
      final quantities = {for (final row in previous) row['source_line_id'] as int: numVal(row['qty'])};
      final newLines = data.map((row) => _ReturnDraft(row, quantities[row['line_id']] ?? 0)).toList();
      if (!mounted) { for (final l in newLines) { l.dispose(); } return; }
      setState(() {
        for (final l in lines) { l.dispose(); }
        lines = newLines;
        documentId = id;
        _syncWalkInRefund();
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { loading = false; error = '$e'; });
    }
  }

  void _syncWalkInRefund() {
    if (walkIn) refund.text = total.toStringAsFixed(2);
  }

  void _setQuantity(_ReturnDraft row, double amount) {
    row.quantity.text = _fmt(amount.clamp(0, row.maxReturn).toDouble());
    _syncWalkInRefund();
    setState(() {});
  }

  Future<void> _save() async {
    if (saving || documentId == null) return;
    final selected = <ReturnItem>[];
    for (final row in lines) {
      final amount = double.tryParse(row.quantity.text);
      if (amount == null || !amount.isFinite || amount < 0 || amount > row.maxReturn + 0.000001) {
        setState(() => error = 'Invalid return quantity for ${row.product}. Maximum: ${_fmt(row.maxReturn)} ${row.unit}.');
        return;
      }
      if (amount > 0) selected.add(ReturnItem(row.lineId, amount));
    }
    if (selected.isEmpty) { setState(() => error = 'Select at least one item to return.'); return; }
    if (accountId == null) { setState(() => error = 'Select a refund payment account.'); return; }
    final amount = walkIn ? total : double.tryParse(refund.text);
    if (amount == null || !amount.isFinite || amount < 0 || amount > total + 0.001) {
      setState(() => error = 'Refund must be between Rs. 0 and Rs. ${total.toStringAsFixed(2)}.');
      return;
    }
    setState(() { saving = true; error = null; });
    try {
      if (editing) {
        await s.reviseReturn(widget.existing!['id'] as int, selected, amount, accountId!, reason.text,
            returnDate: returnDate.text.trim());
      } else {
        await s.postReturn(documentId!, selected, amount, accountId!, reason.text,
            returnDate: returnDate.text.trim());
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    search.dispose();
    refund.dispose();
    reason.dispose();
    returnDate.dispose();
    for (final item in lines) { item.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF183451);
    const blue = Color(0xFF287CF1);
    const light = Color(0xFFF2F7FE);
    final filtered = invoices.where((d) =>
      '${d['invoice']} ${d['party']}'.toLowerCase().contains(search.text.toLowerCase())).toList();
    // On edit, keep the selected invoice present even if search excludes it.
    if (documentId != null && filtered.every((d) => d['id'] != documentId)) {
      filtered.insert(0, invoices.firstWhere((d) => d['id'] == documentId));
    }
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1260, maxHeight: 860),
        child: Column(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(color: navy, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
            child: Row(children: [
              const Icon(Icons.assignment_return_outlined, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(editing ? 'Edit Return #${widget.existing!['id']}' : (sale ? 'Sale Return POS' : 'Purchase Return POS'),
                    style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                Text(sale ? 'Select the original sale and choose the returned variations' : 'Select the original purchase and choose the returned variations',
                    style: const TextStyle(color: Color(0xFFD2E6FF), fontSize: 12)),
              ])),
              IconButton(onPressed: saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white)),
            ])),
          Expanded(child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null && invoices.isEmpty
                  ? Center(child: Text(error!, style: const TextStyle(color: Colors.red)))
                  : SingleChildScrollView(child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        TextField(controller: search, onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.search),
                            labelText: 'Search original invoice number / customer / supplier')),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          key: ValueKey('returnInvoice-$documentId'),
                          initialValue: documentId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Original invoice'),
                          items: filtered.map((d) => DropdownMenuItem<int>(value: d['id'] as int,
                            child: Text('${d['invoice']}  •  ${d['party']}  •  ${d['date']}', overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: editing ? null : (id) { if (id != null) _loadLines(id); },
                        ),
                        const SizedBox(height: 16),
                        Row(children: [
                          const Expanded(child: Text('Return Items / Variations', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: navy))),
                          OutlinedButton.icon(onPressed: lines.isEmpty ? null : () {
                            for (final item in lines) { item.quantity.text = _fmt(item.maxReturn); }
                            _syncWalkInRefund();
                            setState(() {});
                          }, icon: const Icon(Icons.select_all), label: const Text('Full Invoice Return')),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(onPressed: lines.isEmpty ? null : () {
                            for (final item in lines) { item.quantity.text = '0'; }
                            _syncWalkInRefund();
                            setState(() {});
                          }, icon: const Icon(Icons.remove_circle_outline), label: const Text('Clear Selection')),
                        ]),
                        const SizedBox(height: 8),
                        if (lines.isEmpty) Container(padding: const EdgeInsets.all(24),
                          child: const Text('Select an invoice to show its products and variations.')),
                        for (final item in lines) Card(
                          margin: const EdgeInsets.only(bottom: 9),
                          color: light,
                          child: Padding(padding: const EdgeInsets.all(12), child: LayoutBuilder(
                            builder: (context, constraints) {
                              final narrow = constraints.maxWidth < 730;
                              final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(item.product, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: navy)),
                                Text('Variation: ${item.variation}', style: const TextStyle(fontSize: 12, color: Color(0xFF46627E))),
                                const SizedBox(height: 3),
                                Text('Original: ${_fmt(item.original)} ${item.unit}   •   Already returned: ${_fmt(item.previouslyReturned)}   •   Available: ${_fmt(item.maxReturn)}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF46627E))),
                              ]);
                              final input = SizedBox(width: 148, child: Row(children: [
                                IconButton(icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: item.selected <= 0 ? null : () => _setQuantity(item, item.selected - 1)),
                                Expanded(child: TextField(controller: item.quantity,
                                  textAlign: TextAlign.center,
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(isDense: true, labelText: 'Return'),
                                  onChanged: (_) { _syncWalkInRefund(); setState(() {}); })),
                                IconButton(icon: const Icon(Icons.add_circle_outline),
                                  onPressed: item.selected >= item.maxReturn ? null : () => _setQuantity(item, item.selected + 1)),
                              ]));
                              final amount = SizedBox(width: 124, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text('Rs. ${item.rate.toStringAsFixed(2)} / ${item.unit}', style: const TextStyle(fontSize: 11)),
                                Text('Rs. ${item.lineTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ]));
                              if (narrow) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                info, const SizedBox(height: 10), Row(children: [input, const Spacer(), amount]),
                              ]);
                              return Row(children: [Expanded(child: info), input, const SizedBox(width: 16), amount]);
                            },
                          )),
                        ),
                        const Divider(height: 25),
                        Wrap(spacing: 12, runSpacing: 12, children: [
                          SizedBox(width: 175, child: TextField(controller: returnDate,
                            decoration: const InputDecoration(labelText: 'Return Date (YYYY-MM-DD)'))),
                          SizedBox(width: 230, child: TextField(controller: refund,
                            enabled: !walkIn,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(labelText: walkIn ? 'Refund (automatic)' : 'Refund Now (Rs.)'))),
                          SizedBox(width: 275, child: DropdownButtonFormField<int>(
                            key: ValueKey('returnAccount-$accountId'),
                            initialValue: accountId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Cash / Bank / Wallet'),
                            items: paymentAccounts.map((a) => DropdownMenuItem<int>(value: a['id'] as int,
                              child: Text('${a['name']} • ${a['holder']}', overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (id) => setState(() => accountId = id),
                          )),
                          SizedBox(width: 300, child: TextField(controller: reason,
                            decoration: const InputDecoration(labelText: 'Reason / Notes'))),
                        ]),
                        if (error != null) Padding(padding: const EdgeInsets.only(top: 12),
                          child: Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                      ]),
                    ))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            decoration: const BoxDecoration(color: light, borderRadius: BorderRadius.vertical(bottom: Radius.circular(18))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$selectedCount item(s) selected', style: const TextStyle(color: Color(0xFF46627E))),
                Text('Return Value: Rs. ${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: navy)),
                if (walkIn) const Text('Walk-in sale: full cash refund required',
                  style: TextStyle(fontSize: 11, color: Color(0xFF46627E))),
              ])),
              OutlinedButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 12),
              FilledButton.icon(onPressed: saving || documentId == null || selectedCount == 0 ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: blue, minimumSize: const Size(155, 48)),
                icon: const Icon(Icons.save_outlined),
                label: Text(saving ? 'Saving...' : editing ? 'Update Return' : 'Save Return')),
            ])),
        ]),
      ),
    );
  }
}
