import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../data/models/subscription_model.dart';
import '../../presentation/blocs/subscriptions/subscription_bloc.dart';
import '../../presentation/blocs/subscriptions/subscription_event.dart';
import '../../presentation/blocs/subscriptions/subscription_state.dart';
import '../theme/light_color.dart';

/// Common subscription templates for quick selection
class SubscriptionTemplate {
  final String name;
  final String? logoUrl;
  final double defaultAmount;
  final BillingCycle defaultCycle;
  final String color;
  final String category;

  const SubscriptionTemplate({
    required this.name,
    this.logoUrl,
    required this.defaultAmount,
    required this.defaultCycle,
    required this.color,
    required this.category,
  });
}

/// Common subscription services
const List<SubscriptionTemplate> _commonSubscriptions = [
  // Streaming
  SubscriptionTemplate(name: 'Netflix', defaultAmount: 15.99, defaultCycle: BillingCycle.monthly, color: '#E50914', category: 'Streaming'),
  SubscriptionTemplate(name: 'Disney+', defaultAmount: 13.99, defaultCycle: BillingCycle.monthly, color: '#113CCF', category: 'Streaming'),
  SubscriptionTemplate(name: 'Hulu', defaultAmount: 17.99, defaultCycle: BillingCycle.monthly, color: '#1CE783', category: 'Streaming'),
  SubscriptionTemplate(name: 'Spotify', defaultAmount: 10.99, defaultCycle: BillingCycle.monthly, color: '#1DB954', category: 'Music'),
  SubscriptionTemplate(name: 'Apple Music', defaultAmount: 10.99, defaultCycle: BillingCycle.monthly, color: '#FA243C', category: 'Music'),
  SubscriptionTemplate(name: 'Amazon Prime', defaultAmount: 14.99, defaultCycle: BillingCycle.monthly, color: '#FF9900', category: 'Shopping'),
];

/// Page for adding a new subscription
class AddSubscriptionPage extends StatefulWidget {
  const AddSubscriptionPage({super.key});

  @override
  State<AddSubscriptionPage> createState() => _AddSubscriptionPageState();
}

class _AddSubscriptionPageState extends State<AddSubscriptionPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  BillingCycle _billingCycle = BillingCycle.monthly;
  DateTime _nextBillingDate = DateTime.now().add(const Duration(days: 30));
  String _selectedColor = '#CEA734'; // Default to primary gold

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _selectTemplate(SubscriptionTemplate template) {
    setState(() {
      _nameController.text = template.name;
      _amountController.text = template.defaultAmount.toStringAsFixed(2);
      _billingCycle = template.defaultCycle;
      _selectedColor = template.color;
    });
  }

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextBillingDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: LightColor.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: LightColor.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _nextBillingDate = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final request = SubscriptionCreateRequest(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
      amount: double.parse(_amountController.text),
      billingCycle: _billingCycle,
      nextBillingDate: _nextBillingDate,
      color: _selectedColor,
    );

    context.read<SubscriptionBloc>().add(SubscriptionCreateRequested(request: request));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColor.background,
      appBar: AppBar(
        backgroundColor: LightColor.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: LightColor.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add Subscription',
          style: GoogleFonts.mulish(
            color: LightColor.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocConsumer<SubscriptionBloc, SubscriptionState>(
        listener: (context, state) {
          if (state is SubscriptionLoaded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Subscription added!'), backgroundColor: LightColor.safe),
            );
            Navigator.pop(context, true);
          }
        },
        builder: (context, state) {
          final isLoading = state is SubscriptionOperationInProgress;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTemplateSection(),
                      const SizedBox(height: 24),
                      const Divider(color: LightColor.surface, thickness: 1),
                      const SizedBox(height: 20),
                      _buildForm(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(isLoading),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTemplateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Popular Services', style: GoogleFonts.mulish(fontSize: 14, fontWeight: FontWeight.w600, color: LightColor.textSecondary)),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _commonSubscriptions.length,
            itemBuilder: (context, index) => _buildTemplateCard(_commonSubscriptions[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateCard(SubscriptionTemplate template) {
    final isSelected = _nameController.text == template.name;
    final color = Color(int.parse(template.color.replaceFirst('#', '0xFF')));

    return GestureDetector(
      onTap: () => _selectTemplate(template),
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : LightColor.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  template.name[0],
                  style: GoogleFonts.mulish(color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              template.name,
              style: GoogleFonts.mulish(fontSize: 10, fontWeight: FontWeight.w600, color: LightColor.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: _nameController,
            label: 'Service Name',
            hint: 'e.g. Netflix',
            icon: Icons.subscriptions_outlined,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _amountController,
                  label: 'Amount',
                  hint: '0.00',
                  icon: Icons.attach_money,
                  isNumber: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Billing Cycle', style: GoogleFonts.mulish(fontSize: 13, fontWeight: FontWeight.w600, color: LightColor.textSecondary)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: LightColor.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<BillingCycle>(
                          value: _billingCycle,
                          isExpanded: true,
                          items: BillingCycle.values.map((c) => DropdownMenuItem(value: c, child: Text(c.name.toUpperCase(), style: GoogleFonts.mulish(fontSize: 13)))).toList(),
                          onChanged: (v) => setState(() => _billingCycle = v!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Text('First Payment', style: GoogleFonts.mulish(fontSize: 13, fontWeight: FontWeight.w600, color: LightColor.textSecondary)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: LightColor.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: LightColor.textPrimary),
                  const SizedBox(width: 12),
                  Text(DateFormat('MMM d, yyyy').format(_nextBillingDate), style: GoogleFonts.mulish(fontWeight: FontWeight.w600, color: LightColor.textPrimary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.mulish(fontSize: 13, fontWeight: FontWeight.w600, color: LightColor.textSecondary)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          style: GoogleFonts.mulish(fontWeight: FontWeight.w600, color: LightColor.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.mulish(color: LightColor.textTertiary),
            prefixIcon: Icon(icon, color: LightColor.textTertiary, size: 20),
            filled: true,
            fillColor: LightColor.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Required';
            if (isNumber) {
              final parsed = double.tryParse(value);
              if (parsed == null) return 'Enter a valid number';
              if (parsed <= 0) return 'Must be greater than 0';
              if (parsed > 99999.99) return 'Amount too large';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildBottomBar(bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: LightColor.textPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Save Subscription', style: GoogleFonts.mulish(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}