import 'package:flutter/material.dart';

import '../data/inventory_store.dart';
import '../models/inventory.dart';
import '../services/jakstore_api_client.dart';
import '../widgets/status_badge.dart';

Future<bool?> showAddUnitSheet(
  BuildContext context,
  InventoryStore store, {
  String? initialImei,
  String? initialModelId,
  String? identifiedModelId,
  String? identifiedModelName,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AddUnitSheet(
      store: store,
      initialImei: initialImei,
      initialModelId: initialModelId,
      identifiedModelId: identifiedModelId,
      identifiedModelName: identifiedModelName,
    ),
  );
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({required this.store, super.key});

  final InventoryStore store;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final searchController = TextEditingController();
  UnitStatus? selectedStatus;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final query = searchController.text.trim().toLowerCase();
        final filteredModels = widget.store.models.where((model) {
          final units = widget.store.unitsForModel(model.id);
          final matchingUnit = units.any(
            (unit) =>
                unit.imei1.contains(query) ||
                (unit.imei2?.contains(query) ?? false),
          );
          final matchesModel =
              model.displayName.toLowerCase().contains(query) ||
                  widget.store.variantsForModel(model.id).any((variant) =>
                      variant.sku.toLowerCase().contains(query) ||
                      widget.store
                          .variantDescription(variant)
                          .toLowerCase()
                          .contains(query)) ||
                  matchingUnit;
          final matchesStatus = selectedStatus == null ||
              units.any((unit) => unit.status == selectedStatus);
          return matchesModel && matchesStatus;
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Stok barang',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF10172A),
                        ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    if (widget.store.apiClient != null)
                      IconButton.filledTonal(
                        tooltip: 'Tambah model',
                        onPressed: _showCreateModelDialog,
                        icon: const Icon(Icons.phone_android),
                      ),
                    FilledButton.icon(
                      onPressed: _showAddUnitSheet,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Tambah unit'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),
            TextField(
              controller: searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Cari model, varian, atau IMEI',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(
                    label: 'Semua',
                    selected: selectedStatus == null,
                    onTap: () => setState(() => selectedStatus = null),
                  ),
                  for (final status in UnitStatus.values)
                    _FilterChip(
                      label: status.label,
                      selected: selectedStatus == status,
                      onTap: () => setState(() => selectedStatus = status),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${filteredModels.length} model • ${widget.store.units.length} unit fisik',
              style: const TextStyle(
                color: Color(0xFF778196),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.store.apiClient != null &&
                widget.store.models.isEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Katalog belum tersedia. Tambahkan model untuk mulai '
                'mencatat stok.',
                style: TextStyle(color: Color(0xFF778196), fontSize: 12),
              ),
            ],
            const SizedBox(height: 9),
            if (filteredModels.isEmpty)
              const _EmptyInventory()
            else
              ...filteredModels.map(
                (model) => _ModelCard(
                  store: widget.store,
                  model: model,
                  statusFilter: selectedStatus,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ModelDetailScreen(
                        store: widget.store,
                        model: model,
                        statusFilter: selectedStatus,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showCreateModelDialog() async {
    final model = await showDialog<ProductModel>(
      context: context,
      builder: (_) => _CreateModelDialog(store: widget.store),
    );
    if (model != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ModelDetailScreen(store: widget.store, model: model),
        ),
      );
    }
  }

  Future<void> _showAddUnitSheet() async {
    final result = await showAddUnitSheet(context, widget.store);
    if (result == true && mounted) {
      final warning = widget.store.takeSyncWarning();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(warning ?? 'Unit baru berhasil ditambahkan.'),
        ),
      );
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          showCheckmark: false,
          selectedColor: const Color(0xFFFFE9DE),
          labelStyle: TextStyle(
            color: selected ? const Color(0xFFC84C18) : const Color(0xFF657084),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          side: BorderSide(
            color: selected ? const Color(0xFFFF6A2A) : const Color(0xFFE4E7ED),
          ),
        ),
      );
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.store,
    required this.model,
    required this.statusFilter,
    required this.onTap,
  });

  final InventoryStore store;
  final ProductModel model;
  final UnitStatus? statusFilter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final units = store.unitsForModel(model.id);
    final available =
        units.where((unit) => unit.status == UnitStatus.available).length;
    final visibleUnits = statusFilter == null
        ? units
        : units.where((unit) => unit.status == statusFilter).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE9EBF1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F7),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.smartphone_rounded,
                  color: Color(0xFF10172A),
                  size: 28,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${units.length} unit fisik',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF778196),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          '$available tersedia',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (visibleUnits.length != units.length)
                          Text(
                            '• ${visibleUnits.length} sesuai filter',
                            style: const TextStyle(fontSize: 10),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF9AA3B2)),
            ],
          ),
        ),
      ),
    );
  }
}

class ModelDetailScreen extends StatelessWidget {
  const ModelDetailScreen({
    required this.store,
    required this.model,
    this.statusFilter,
    super.key,
  });

  final InventoryStore store;
  final ProductModel model;
  final UnitStatus? statusFilter;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final variants = store.variantsForModel(model.id);
        final units = store.unitsForModel(model.id);
        final visibleVariants = variants.where((variant) {
          if (statusFilter == null) return true;
          return store
              .unitsFor(variant.id)
              .any((unit) => unit.status == statusFilter);
        }).toList(growable: false);
        return Scaffold(
          appBar: AppBar(title: const Text('Detail model')),
          body: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF10172A),
                  borderRadius: BorderRadius.circular(23),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.smartphone_rounded,
                      color: Color(0xFFFF8A58),
                      size: 30,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      model.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text('${units.length} unit fisik',
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Varian',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Text('${visibleVariants.length} varian'),
                ],
              ),
              if (store.apiClient != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _showCreateVariantDialog(context, store, model),
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah varian'),
                  ),
                ),
              ],
              const SizedBox(height: 9),
              if (variants.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Belum ada varian konfigurasi untuk model ini.'),
                ),
              if (visibleVariants.isEmpty && variants.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Tidak ada varian yang cocok dengan filter ini.'),
                ),
              ...visibleVariants.map((variant) {
                final variantUnits = store.unitsFor(variant.id);
                final matchingUnits = statusFilter == null
                    ? variantUnits
                    : variantUnits
                        .where((unit) => unit.status == statusFilter)
                        .toList(growable: false);
                return _VariantCard(
                  store: store,
                  variant: variant,
                  units: variantUnits,
                  visibleUnitCount: matchingUnits.length,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => VariantDetailScreen(
                        store: store,
                        model: model,
                        variant: variant,
                        statusFilter: statusFilter,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _VariantCard extends StatelessWidget {
  const _VariantCard({
    required this.store,
    required this.variant,
    required this.units,
    required this.visibleUnitCount,
    required this.onTap,
  });

  final InventoryStore store;
  final ProductVariant variant;
  final List<PhoneUnit> units;
  final int visibleUnitCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final availableUnits =
        units.where((unit) => unit.status == UnitStatus.available).length;
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: const BorderSide(color: Color(0xFFE9EBF1)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.palette_outlined, color: Color(0xFF778196)),
        title: Text(
          store.variantDescription(variant),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        subtitle: Text(
          '${units.length} unit fisik • $availableUnits tersedia'
          '${visibleUnitCount == units.length ? '' : ' • $visibleUnitCount sesuai filter'}',
          style: const TextStyle(fontSize: 11, color: Color(0xFF778196)),
        ),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF9AA3B2)),
      ),
    );
  }
}

class VariantDetailScreen extends StatelessWidget {
  const VariantDetailScreen({
    required this.store,
    required this.model,
    required this.variant,
    this.statusFilter,
    super.key,
  });

  final InventoryStore store;
  final ProductModel model;
  final ProductVariant variant;
  final UnitStatus? statusFilter;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final allUnits = store.unitsFor(variant.id);
        final units = statusFilter == null
            ? allUnits
            : allUnits
                .where((unit) => unit.status == statusFilter)
                .toList(growable: false);
        return Scaffold(
          appBar: AppBar(title: const Text('Detail varian')),
          body: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text(
                model.displayName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                store.variantDescription(variant),
                style: const TextStyle(
                  color: Color(0xFF778196),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Unit fisik',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Text('${units.length} unit'),
                ],
              ),
              const SizedBox(height: 9),
              if (units.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Belum ada unit yang cocok dengan filter ini.'),
                ),
              ...units.map(
                (unit) => _UnitCard(
                  unit: unit,
                  variant: variant,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          UnitDetailScreen(store: store, unitId: unit.id),
                    ),
                  ),
                  onStatusChanged: (status) async {
                    final error =
                        await store.updateUnitStatusOnline(unit.id, status);
                    if (error != null && context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(error)));
                    } else if (context.mounted) {
                      final warning = store.takeSyncWarning();
                      if (warning != null) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(warning)));
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.unit,
    required this.variant,
    required this.onTap,
    required this.onStatusChanged,
  });

  final PhoneUnit unit;
  final ProductVariant? variant;
  final VoidCallback onTap;
  final ValueChanged<UnitStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE9EBF1)),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          children: [
            const Icon(Icons.phone_iphone, color: Color(0xFF778196)),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    maskImei(unit.imei1),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  if (variant != null)
                    Text(
                      '${variant!.color} • ${variant!.ram == null ? variant!.storage : '${variant!.ram} / ${variant!.storage}'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF778196),
                      ),
                    ),
                  if (unit.imei2 != null)
                    Text(
                      'IMEI 2: ${maskImei(unit.imei2!)}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF778196),
                      ),
                    ),
                  const SizedBox(height: 5),
                  StatusBadge(status: unit.status),
                ],
              ),
            ),
            PopupMenuButton<UnitStatus>(
              tooltip: 'Ubah status unit',
              onSelected: onStatusChanged,
              itemBuilder: (_) => UnitStatus.values
                  .where(
                    (status) =>
                        status != unit.status && status != UnitStatus.sold,
                  )
                  .map(
                    (status) =>
                        PopupMenuItem(value: status, child: Text(status.label)),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class UnitDetailScreen extends StatelessWidget {
  const UnitDetailScreen({
    required this.store,
    required this.unitId,
    super.key,
  });

  final InventoryStore store;
  final String unitId;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final unit = store.unitById(unitId);
          final variant =
              unit == null ? null : store.variantFor(unit.variantId);
          final model =
              variant == null ? null : store.modelFor(variant.modelId);
          if (unit == null || variant == null) {
            return const Scaffold(
              body: Center(child: Text('Unit tidak ditemukan.')),
            );
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Detail unit')),
            body: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Text(
                  model?.displayName ?? 'Model tidak ditemukan',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 16),
                _UnitDetailField(label: 'IMEI 1', value: unit.imei1),
                if (unit.imei2 != null)
                  _UnitDetailField(label: 'IMEI 2', value: unit.imei2!),
                _UnitDetailField(label: 'Warna', value: variant.color),
                if (variant.ram != null)
                  _UnitDetailField(label: 'RAM', value: variant.ram!),
                _UnitDetailField(
                  label: 'Penyimpanan',
                  value: variant.storage,
                ),
                _UnitDetailField(label: 'Status', value: unit.status.label),
                _UnitDetailField(
                  label: 'Dicatat',
                  value: unit.recordedAt.toLocal().toString(),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<UnitStatus>(
                  initialValue: unit.status,
                  decoration: const InputDecoration(labelText: 'Ubah status'),
                  items: UnitStatus.values
                      .where((status) =>
                          status != UnitStatus.sold || status == unit.status)
                      .map((status) => DropdownMenuItem(
                            value: status,
                            child: Text(status.label),
                          ))
                      .toList(),
                  onChanged: unit.status == UnitStatus.sold
                      ? null
                      : (status) async {
                          if (status == null || status == unit.status) return;
                          final error = await store.updateUnitStatusOnline(
                            unit.id,
                            status,
                          );
                          if (error != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error)),
                            );
                          }
                        },
                ),
              ],
            ),
          );
        },
      );
}

class _UnitDetailField extends StatelessWidget {
  const _UnitDetailField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF778196))),
            const SizedBox(height: 4),
            SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
}

class _AddUnitSheet extends StatefulWidget {
  const _AddUnitSheet({
    required this.store,
    this.initialImei,
    this.initialModelId,
    this.identifiedModelId,
    this.identifiedModelName,
  });

  final InventoryStore store;
  final String? initialImei;
  final String? initialModelId;
  final String? identifiedModelId;
  final String? identifiedModelName;

  @override
  State<_AddUnitSheet> createState() => _AddUnitSheetState();
}

class _AddUnitSheetState extends State<_AddUnitSheet> {
  final formKey = GlobalKey<FormState>();
  late final imei1Controller =
      TextEditingController(text: widget.initialImei ?? '');
  final imei2Controller = TextEditingController();
  final noteController = TextEditingController();
  List<ProductModel> get selectableModels =>
      widget.store.models.where((model) => model.active).toList();

  late String selectedModelId = selectableModels.any(
    (model) => model.id == widget.initialModelId,
  )
      ? widget.initialModelId!
      : selectableModels.isEmpty
          ? ''
          : selectableModels.first.id;
  List<ProductVariant> get selectableVariants =>
      widget.store.variantsForModel(selectedModelId);
  late String variantId =
      selectableVariants.isEmpty ? '' : selectableVariants.first.id;
  UnitStatus initialStatus = UnitStatus.available;
  String? submissionError;
  bool saving = false;

  @override
  void dispose() {
    imei1Controller.dispose();
    imei2Controller.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: formKey,
        child: ListView(
          key: const ValueKey('add-unit-form-list'),
          shrinkWrap: true,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8DCE5),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Tambah unit baru',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            if (widget.initialModelId != null &&
                selectedModelId == widget.initialModelId) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 11),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7F0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Model teridentifikasi: '
                  '${widget.store.modelFor(selectedModelId)?.displayName}. '
                  'Periksa warna, RAM, dan penyimpanan unit.',
                  style: const TextStyle(
                    color: Color(0xFF176B4C),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            if (selectableModels.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Belum ada model di katalog.'),
                  if (widget.store.apiClient != null)
                    TextButton.icon(
                      onPressed: _createModel,
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah model'),
                    ),
                ],
              )
            else ...[
              DropdownButtonFormField<String>(
                key: const ValueKey('add-unit-model-selector'),
                initialValue: selectedModelId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Model HP'),
                items: selectableModels
                    .map(
                      (model) => DropdownMenuItem(
                        value: model.id,
                        child: Text(
                          model.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedModelId = value;
                      final variants = widget.store.variantsForModel(value);
                      variantId = variants.isEmpty ? '' : variants.first.id;
                      submissionError = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 11),
              if (selectableVariants.isEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Belum ada varian warna/RAM/penyimpanan.'),
                    if (widget.store.apiClient != null)
                      TextButton.icon(
                        onPressed: _createVariant,
                        icon: const Icon(Icons.add),
                        label: const Text('Tambah varian untuk model ini'),
                      ),
                  ],
                )
              else
                DropdownButtonFormField<String>(
                  key: const ValueKey('add-unit-variant-selector'),
                  initialValue: variantId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Warna / RAM / penyimpanan',
                  ),
                  items: selectableVariants
                      .map(
                        (variant) => DropdownMenuItem(
                          value: variant.id,
                          child: Text(
                            widget.store.variantDescription(variant),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        variantId = value;
                        submissionError = null;
                      });
                    }
                  },
                ),
              if (widget.store.apiClient != null &&
                  selectableVariants.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _createVariant,
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah konfigurasi varian'),
                  ),
                ),
            ],
            const SizedBox(height: 11),
            DropdownButtonFormField<UnitStatus>(
              initialValue: initialStatus,
              decoration: const InputDecoration(labelText: 'Status awal'),
              items: UnitStatus.values
                  .where((status) => status != UnitStatus.sold)
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(status.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => initialStatus = value);
              },
            ),
            const SizedBox(height: 11),
            TextFormField(
              controller: imei1Controller,
              keyboardType: TextInputType.number,
              maxLength: 15,
              decoration: const InputDecoration(
                labelText: 'IMEI 1',
                hintText: '15 digit',
                counterText: '',
              ),
              validator: (value) => value == null || !isValidImei(value.trim())
                  ? 'Masukkan IMEI 15 digit yang valid.'
                  : null,
              onChanged: (_) {
                if (submissionError != null) {
                  setState(() => submissionError = null);
                }
              },
            ),
            const SizedBox(height: 11),
            TextFormField(
              controller: imei2Controller,
              keyboardType: TextInputType.number,
              maxLength: 15,
              decoration: const InputDecoration(
                labelText: 'IMEI 2 (opsional)',
                hintText: '15 digit',
                counterText: '',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                if (value.trim() == imei1Controller.text.trim()) {
                  return 'IMEI 1 dan IMEI 2 tidak boleh sama.';
                }
                return isValidImei(value.trim())
                    ? null
                    : 'IMEI 2 harus berupa 15 digit yang valid.';
              },
              onChanged: (_) {
                if (submissionError != null) {
                  setState(() => submissionError = null);
                }
              },
            ),
            const SizedBox(height: 11),
            TextFormField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                hintText: 'Pemasok / nomor dokumen',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.store.apiClient == null
                  ? 'Data tersimpan di mock lokal sementara aplikasi berjalan.'
                  : 'Data akan disimpan ke server JakStore.',
              style: const TextStyle(color: Color(0xFF778196), fontSize: 11),
            ),
            if (submissionError != null) ...[
              const SizedBox(height: 8),
              Text(
                submissionError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 15),
            FilledButton(
              onPressed: selectableVariants.isEmpty || saving ? null : _save,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Simpan Barang'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (selectableVariants.isEmpty) {
      setState(() {
        submissionError = 'Tambahkan model dan varian sebelum mencatat stok.';
      });
      return;
    }
    if (!formKey.currentState!.validate()) return;
    final identifiedModelName = widget.identifiedModelName;
    if (identifiedModelName != null &&
        selectedModelId != widget.identifiedModelId) {
      final selectedModel = widget.store.modelFor(selectedModelId);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Konfirmasi model'),
          content: Text(
            'Lookup mengidentifikasi $identifiedModelName, tetapi model yang '
            'dipilih adalah ${selectedModel?.displayName ?? 'tidak diketahui'}. '
            'Tetap simpan unit ke model yang dipilih?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Kembali'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Tetap lanjutkan'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() {
      saving = true;
      submissionError = null;
    });
    try {
      final error = await widget.store.addUnitOnline(
        variantId: variantId,
        imei1: imei1Controller.text,
        imei2: imei2Controller.text,
        note: noteController.text.trim(),
        status: initialStatus,
      );
      if (error != null) {
        setState(() => submissionError = error);
        return;
      }
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _createModel() async {
    final model = await showCreateModelDialog(context, widget.store);
    if (model == null || !mounted) return;
    setState(() {
      selectedModelId = model.id;
      variantId = '';
      submissionError = null;
    });
  }

  Future<void> _createVariant() async {
    final model = widget.store.modelFor(selectedModelId);
    if (model == null) return;
    final variant = await showCreateVariantDialog(context, widget.store, model);
    if (variant == null || !mounted) return;
    setState(() {
      selectedModelId = model.id;
      variantId = variant.id;
      submissionError = null;
    });
  }
}

Future<ProductModel?> showCreateModelDialog(
  BuildContext context,
  InventoryStore store,
) =>
    showDialog<ProductModel>(
      context: context,
      builder: (_) => _CreateModelDialog(store: store),
    );

Future<ProductVariant?> showCreateVariantDialog(
  BuildContext context,
  InventoryStore store,
  ProductModel model,
) =>
    showDialog<ProductVariant>(
      context: context,
      builder: (_) => _CreateVariantDialog(store: store, model: model),
    );

Future<ProductVariant?> _showCreateVariantDialog(
  BuildContext context,
  InventoryStore store,
  ProductModel model,
) =>
    showCreateVariantDialog(context, store, model);

class _CreateModelDialog extends StatefulWidget {
  const _CreateModelDialog({required this.store});

  final InventoryStore store;

  @override
  State<_CreateModelDialog> createState() => _CreateModelDialogState();
}

class _CreateModelDialogState extends State<_CreateModelDialog> {
  final _formKey = GlobalKey<FormState>();
  final _brandController = TextEditingController();
  final _nameController = TextEditingController();
  final _modelCodeController = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _brandController.dispose();
    _nameController.dispose();
    _modelCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Tambah model HP'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _brandController,
                  decoration: const InputDecoration(labelText: 'Merek'),
                  validator: _required,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameController,
                  decoration:
                      const InputDecoration(labelText: 'Nama model saja'),
                  validator: _required,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _modelCodeController,
                  decoration:
                      const InputDecoration(labelText: 'Kode model (opsional)'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Simpan model'),
          ),
        ],
      );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Wajib diisi.' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final model = await widget.store.createCatalogModel(
        brand: _brandController.text,
        name: _nameController.text,
        modelCode: _modelCodeController.text,
      );
      if (mounted) Navigator.pop(context, model);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _CreateVariantDialog extends StatefulWidget {
  const _CreateVariantDialog({required this.store, required this.model});

  final InventoryStore store;
  final ProductModel model;

  @override
  State<_CreateVariantDialog> createState() => _CreateVariantDialogState();
}

class _CreateVariantDialogState extends State<_CreateVariantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _colorController = TextEditingController();
  final _ramController = TextEditingController();
  final _storageController = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _colorController.dispose();
    _ramController.dispose();
    _storageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Tambah varian ${widget.model.displayName}'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _colorController,
                  decoration: const InputDecoration(labelText: 'Warna'),
                  validator: _required,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _ramController,
                  decoration: const InputDecoration(
                    labelText: 'RAM (contoh: 8 GB)',
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _storageController,
                  decoration: const InputDecoration(
                    labelText: 'Penyimpanan (contoh: 256 GB)',
                  ),
                  validator: _required,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Simpan varian'),
          ),
        ],
      );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Wajib diisi.' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final variant = await widget.store.createCatalogVariant(
        modelId: widget.model.id,
        color: _colorController.text,
        ram: _ramController.text,
        storage: _storageController.text,
      );
      if (mounted) Navigator.pop(context, variant);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _EmptyInventory extends StatelessWidget {
  const _EmptyInventory();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          children: [
            Icon(Icons.search_off, size: 34, color: Color(0xFF9AA3B2)),
            SizedBox(height: 9),
            Text('Data tidak ditemukan'),
            SizedBox(height: 4),
            Text(
              'Coba ubah kata pencarian atau filter status.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF778196)),
            ),
          ],
        ),
      );
}
