import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../presentation/blocs/auth/auth_bloc.dart';
import '../../presentation/blocs/auth/auth_event.dart';
import '../../presentation/blocs/auth/auth_state.dart';
import '../theme/light_color.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({Key? key}) : super(key: key);

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    _fullNameController = TextEditingController(
      text: authState is AuthAuthenticated
          ? authState.user.fullName ?? ''
          : '',
    );
    _fullNameController.addListener(() {
      if (!_hasChanges) setState(() => _hasChanges = true);
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            AuthUpdateProfileRequested(
              fullName: _fullNameController.text.trim(),
            ),
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile updated',
            style: GoogleFonts.mulish(fontWeight: FontWeight.w600),
          ),
          backgroundColor: LightColor.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColor.background,
      appBar: AppBar(
        backgroundColor: LightColor.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: LightColor.titleTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.mulish(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: LightColor.titleTextColor,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _saveProfile,
              child: Text(
                'Save',
                style: GoogleFonts.mulish(
                  color: LightColor.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is! AuthAuthenticated) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = state.user;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [LightColor.accent, LightColor.navyBlue1],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(user.fullName ?? user.email),
                        style: GoogleFonts.mulish(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Full Name
                  TextFormField(
                    controller: _fullNameController,
                    style: GoogleFonts.mulish(
                      color: LightColor.titleTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      labelStyle: GoogleFonts.mulish(color: LightColor.subTitleTextColor),
                      filled: true,
                      fillColor: LightColor.lightGrey,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.person_rounded, color: LightColor.accent),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Email (read-only)
                  TextFormField(
                    initialValue: user.email,
                    readOnly: true,
                    style: GoogleFonts.mulish(
                      color: LightColor.subTitleTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: GoogleFonts.mulish(color: LightColor.subTitleTextColor),
                      filled: true,
                      fillColor: LightColor.lightGrey,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.email_rounded, color: LightColor.grey),
                      suffixIcon: const Icon(Icons.lock_rounded, color: LightColor.grey, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Email cannot be changed',
                      style: GoogleFonts.mulish(
                        fontSize: 12,
                        color: LightColor.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Account Info
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: LightColor.lightGrey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Info',
                          style: GoogleFonts.mulish(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: LightColor.titleTextColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow('Plan', user.subscriptionTierDisplay.toUpperCase()),
                        const SizedBox(height: 8),
                        _buildInfoRow('Member since', _formatDate(user.createdAt)),
                        const SizedBox(height: 8),
                        _buildInfoRow('Verified', user.isVerified ? 'Yes' : 'No'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _hasChanges ? _saveProfile : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LightColor.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: LightColor.grey.withOpacity(0.3),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Save Changes',
                        style: GoogleFonts.mulish(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.mulish(fontSize: 13, color: LightColor.subTitleTextColor),
        ),
        Text(
          value,
          style: GoogleFonts.mulish(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: LightColor.titleTextColor,
          ),
        ),
      ],
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
