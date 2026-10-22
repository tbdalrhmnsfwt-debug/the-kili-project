/// The subscription screen: the term and annual plans.
///
/// Purchases run through Google Play Billing ([BillingService]) and receipts
/// are forwarded to the backend for validation. When Play Billing is not
/// available the screen still shows the plans and links to the store's
/// subscription manager, instead of pretending the user can pay in-app.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/billing_service.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';

/// Where the user manages their Google Play subscription.
const String kPlaySubscriptionsUrl =
    'https://play.google.com/store/account/subscriptions?package=com.zakerly.ai';

/// The subscription screen.
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    final billing = ref.read(billingServiceProvider);
    billing.loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    final billing = ref.watch(billingServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('الاشتراكات والمدفوعات')),
      body: ListenableBuilder(
        listenable: billing,
        builder: (context, _) {
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.all(ZakerSpacing.lg),
            children: [
              _StatusCard(billing: billing),
              const SizedBox(height: ZakerSpacing.lg),
              const SectionHeader(
                title: 'الخطط',
                icon: Icons.workspace_premium_rounded,
              ),
              for (final offer in billing.offers)
                _PlanCard(
                  plan: offer.plan,
                  product: offer.product,
                  inactive: billing.state == SubscriptionState.notAvailable,
                  onBuy: offer.product == null
                      ? null
                      : () => _buy(billing, offer.product!),
                ),
              const SizedBox(height: ZakerSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: billing.state == SubscriptionState.notAvailable
                          ? null
                          : billing.restore,
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text('استرجاع الشراء'),
                    ),
                  ),
                  const SizedBox(width: ZakerSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _manage,
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('إدارة في Play'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZakerSpacing.xl),
              Text(
                billing.state == SubscriptionState.notAvailable
                    ? 'خدمة الدفع من Google Play مش متاحة على الجهاز ده. '
                          'تقدر تدير اشتراكك من متجر Play.'
                    : 'الدفع بيتم من Google Play، والسيرفر بيتحقق من الإيصال '
                          'قبل تفعيل الاشتراك.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (billing.lastError != null) ...[
                const SizedBox(height: ZakerSpacing.md),
                Text(
                  'آخر خطأ: ${billing.lastError}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _buy(BillingService billing, ProductDetails product) async {
    final started = await billing.buy(product);
    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مش قادر أبدأ عملية الشراء.')),
      );
    }
  }

  void _manage() {
    launchUrl(
      Uri.parse(kPlaySubscriptionsUrl),
      mode: LaunchMode.externalApplication,
    );
  }
}

/// The current subscription state.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.billing});

  final BillingService billing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, detail, icon) = switch (billing.state) {
      SubscriptionState.active => (
        'الاشتراك مفعّل',
        billing.activeProductId ?? 'خطة نشطة',
        Icons.verified_rounded,
      ),
      SubscriptionState.free => (
        'مفيش اشتراك',
        'كل المزايا الأساسية متاحة مجانًا.',
        Icons.person_outline_rounded,
      ),
      SubscriptionState.notAvailable => (
        'الدفع غير متاح',
        'Play Billing مش متاح على الجهاز.',
        Icons.storefront_outlined,
      ),
      SubscriptionState.unknown => (
        'جاري التحقق…',
        'بنسأل متجر Play عن اشتراكك.',
        Icons.sync_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: ZakerRadius.card,
        gradient: LinearGradient(
          colors: billing.state == SubscriptionState.active
              ? [ZakerColors.success, const Color(0xFF2E7D32)]
              : [theme.colorScheme.primary, ZakerColors.primaryLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(width: ZakerSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
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

/// One plan card.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.product,
    required this.inactive,
    required this.onBuy,
  });

  final SubscriptionPlan plan;
  final ProductDetails? product;
  final bool inactive;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = product?.price;
    return Container(
      margin: const EdgeInsets.only(bottom: ZakerSpacing.md),
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                price ?? plan.period,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.xs),
          Text(
            plan.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: ZakerSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: inactive ? null : onBuy,
              child: Text(
                inactive ? 'غير متاح على الجهاز' : 'اشترك — ${plan.period}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
