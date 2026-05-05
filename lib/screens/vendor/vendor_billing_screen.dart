import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';

class VendorBillingScreen extends StatelessWidget {
  const VendorBillingScreen({super.key});

  Future<void> _contactWhatsApp(BuildContext context) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('platform')
          .doc('settings')
          .get();
      final number = snap.data()?['whatsappNumber'] as String?;

      if (number != null && number.isNotEmpty) {
        final cleanNumber = number.replaceAll(RegExp(r'[^\d+]'), '');
        final url = Uri.parse('https://wa.me/${cleanNumber.replaceAll('+', '')}');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          final telUrl = Uri.parse('tel:$cleanNumber');
          if (await canLaunchUrl(telUrl)) {
            await launchUrl(telUrl);
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not open WhatsApp.')),
              );
            }
          }
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Support number not configured yet.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Text(
                  'Billing & Plans',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ),
          ),
          if (vendorId != null)
            SliverToBoxAdapter(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('businesses').doc(vendorId).snapshots(),
                builder: (context, bizSnap) {
                  if (!bizSnap.hasData) return const SizedBox.shrink();
                  
                  final bizData = bizSnap.data?.data() as Map<String, dynamic>? ?? {};
                  final status = bizData['subscriptionStatus'] as String? ?? 'none';
                  final planId = bizData['planId'] as String? ?? 'None';
                  final currentPeriodEnd = bizData['currentPeriodEnd'] as Timestamp?;
                  
                  final now = DateTime.now();
                  final endDate = currentPeriodEnd?.toDate() ?? now;
                  final daysRemaining = endDate.difference(now).inDays;
                  final isExpired = daysRemaining < 0;

                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusCard(status, planId, daysRemaining, isExpired),
                        const SizedBox(height: 32),
                        Text(
                          'Available Plans',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('platform').doc('settings').snapshots(),
                          builder: (context, settingsSnap) {
                            if (!settingsSnap.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            
                            final data = settingsSnap.data?.data() as Map<String, dynamic>? ?? {};
                            final plans = data['plans'] as List<dynamic>? ?? [];

                            if (plans.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Text('No plans available yet.'),
                              );
                            }

                            return Column(
                              children: plans.map((plan) {
                                final pId = plan['id'] as String? ?? '';
                                final pName = plan['name'] as String? ?? 'Plan';
                                final pPrice = plan['price'] as int? ?? 0;
                                final pFeatures = plan['features'] as String? ?? '';
                                final featuresList = pFeatures.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

                                final isCurrent = planId == pId;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: isCurrent ? AppColors.primaryContainer : AppColors.surface,
                                    border: Border.all(
                                      color: isCurrent ? AppColors.primary : AppColors.outlineVariant,
                                      width: isCurrent ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            pName,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.onSurface,
                                            ),
                                          ),
                                          Text(
                                            'R $pPrice /mo',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      ...featuresList.map((f) => Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          children: [
                                            Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), size: 16, color: AppColors.primary),
                                            const SizedBox(width: 8),
                                            Text(f, style: TextStyle(color: AppColors.onSurfaceVariant)),
                                          ],
                                        ),
                                      )),
                                      const SizedBox(height: 16),
                                      // Payment instruction
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE7F8EE),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.4)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.info_outline, size: 16, color: Color(0xFF128C7E)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'To subscribe or renew, send us a WhatsApp message and we will process your payment manually.',
                                                style: GoogleFonts.beVietnamPro(
                                                  fontSize: 12,
                                                  color: const Color(0xFF075E54),
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () => _contactWhatsApp(context),
                                          icon: const Icon(Icons.chat, size: 20),
                                          label: Text(
                                            isCurrent ? 'Renew via WhatsApp' : 'Subscribe via WhatsApp',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF25D366),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String status, String planId, int daysRemaining, bool isExpired) {
    Color bgColor;
    Color iconColor;
    IconData icon;
    String statusText;

    if (status == 'active' || status == 'trialing') {
      bgColor = Colors.green[50]!;
      iconColor = Colors.green[600]!;
      icon = PhosphorIcons.checkCircle(PhosphorIconsStyle.fill);
      statusText = status == 'trialing' ? 'On Trial' : 'Active';
    } else if (status == 'past_due' || (daysRemaining >= 0 && daysRemaining <= 3)) {
      bgColor = Colors.orange[50]!;
      iconColor = Colors.orange[600]!;
      icon = PhosphorIcons.warningCircle(PhosphorIconsStyle.fill);
      statusText = status == 'past_due' ? 'Grace Period' : 'Expiring Soon';
    } else {
      bgColor = Colors.red[50]!;
      iconColor = Colors.red[600]!;
      icon = PhosphorIcons.xCircle(PhosphorIconsStyle.fill);
      statusText = 'Expired';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: $statusText',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isExpired 
                    ? 'Your subscription has ended.' 
                    : 'You have $daysRemaining day${daysRemaining == 1 ? '' : 's'} remaining.',
                  style: TextStyle(
                    fontSize: 14,
                    color: iconColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
