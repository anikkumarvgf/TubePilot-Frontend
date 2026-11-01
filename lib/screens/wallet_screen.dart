import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/app_brand_background.dart';
import '../widgets/diwali_decor.dart';
import '../providers/language_provider.dart';
import 'diamond_store_screen.dart';

/// Subscription & Wallet — ONE page:
///   Balance card (+ Subscribe button -> DiamondStoreScreen)
///   Tabs: Transactions | Purchases | Refunds (old "Wallet & Refund Logs")
/// All numbers come from GET /wallet and GET /wallet/refunds (real data only).
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Map<String, dynamic>? wallet;
  bool loading = true;
  int _tab = 0; // 0 transactions, 1 purchases, 2 refunds

  // Refund logs
  int _days = 30;
  bool _refundsLoading = false;
  bool _refundsLoaded = false;
  List<Map<String, dynamic>> _refunds = [];
  int _totalRefunded = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final res = await ApiService.instance.getWallet();
      if (mounted) setState(() => wallet = res['wallet']);
      if (_refundsLoaded) await _loadRefunds();
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadRefunds() async {
    setState(() => _refundsLoading = true);
    try {
      final res = await ApiService.instance.getRefundLogs(days: _days);
      if (!mounted) return;
      setState(() {
        _refunds = ((res['refunds'] as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _totalRefunded = (res['totalDiamondsRefunded'] as num?)?.toInt() ?? 0;
        _refundsLoaded = true;
      });
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _refundsLoading = false);
    }
  }

  void _selectTab(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    if (i == 2 && !_refundsLoaded) _loadRefunds();
  }

  void _pickRange() {
    showModalBottomSheet(
      context: context,
      backgroundColor: DiwaliColors.creamTop,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          for (final d in const [7, 30, 90])
            ListTile(
              title: Text(context.tr('wr_last_days').replaceAll('%1', '$d'),
                  style: const TextStyle(fontWeight: FontWeight.w600, color: DiwaliColors.purpleDark)),
              trailing: _days == d ? const Icon(Icons.check_rounded, color: AppColors.purple) : null,
              onTap: () {
                Navigator.pop(c);
                if (_days != d) {
                  _days = d;
                  _loadRefunds();
                }
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  (Color, String) _statusBadge(BuildContext context, String status) {
    switch (status) {
      case 'pending': return (AppColors.diamond, context.tr('status_pending'));
      case 'approved': return (AppColors.green, context.tr('status_approved'));
      case 'rejected': return (AppColors.red, context.tr('status_rejected'));
      case 'completed': return (AppColors.green, context.tr('status_completed'));
      default: return (AppColors.diamond, status);
    }
  }

  (IconData, Color) _txnIcon(Map t, bool isSpend) {
    if (t['type'] == 'diamond_purchase') return (Icons.diamond_rounded, AppColors.diamond);
    if (t['type'] == 'subscription_charge') return (Icons.autorenew_rounded, AppColors.purple);
    if (isSpend) return (Icons.upload_rounded, AppColors.red);
    return (Icons.replay_rounded, AppColors.green);
  }

  String _formatDate(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AppBrandBackground(
      watermarkWhenNormal: false,
      child: _buildScreen(context),
    );
  }

  Widget _buildScreen(BuildContext context) {
    final all = (wallet?['transactions'] as List?) ?? [];
    final purchasesOnly = all.where((t) => t['type'] == 'diamond_purchase' || t['type'] == 'subscription_charge').toList();
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(context.tr('wallet_title'), style: const TextStyle(color: DiwaliColors.purpleDark, fontWeight: FontWeight.w800)),
      ),
      body: loading
          ? const LoadingView()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.purple,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
                children: [
                  _balanceCard(),
                  const SizedBox(height: 16),
                  _tabs(),
                  const SizedBox(height: 14),
                  if (_tab == 0) _buildList(context, all),
                  if (_tab == 1) _buildList(context, purchasesOnly),
                  if (_tab == 2) _refundsView(),
                ],
              ),
            ),
    );
  }

  Widget _balanceCard() {
    return DiwaliCard(
      padding: const EdgeInsets.all(18),
      child: Column(children: [
        Text(context.tr('total_diamonds'), style: const TextStyle(color: DiwaliColors.textDim, fontSize: 13)),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.diamond_rounded, color: AppColors.diamond, size: 26),
          const SizedBox(width: 8),
          Text('${wallet?['diamondBalance'] ?? 0}',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: DiwaliColors.purpleDark)),
        ]),
        const SizedBox(height: 6),
        Text(
          context.tr('free_uploads_remaining').replaceAll('%d', '${wallet?['freeUploadsRemaining'] ?? 0}'),
          style: const TextStyle(color: DiwaliColors.textDim, fontSize: 12.5),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiamondStoreScreen())).then((_) => _load()),
            icon: const Icon(Icons.workspace_premium_rounded, size: 20),
            label: const Text('Subscribe / Buy Diamonds', style: TextStyle(fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: DiwaliColors.purple,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _tabs() {
    final labels = [context.tr('transactions_tab'), context.tr('purchases_tab'), 'Refunds'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => _selectTab(i),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _tab == i ? DiwaliColors.purple : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _tab == i ? DiwaliColors.purple : DiwaliColors.cardBorder.withValues(alpha: 0.7)),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(labels[i],
                      style: TextStyle(color: _tab == i ? Colors.white : DiwaliColors.purpleDark, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------- Refunds tab (was "Wallet & Refund Logs") ----------------
  Widget _refundsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text(context.tr('auto_refund_history'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: DiwaliColors.purpleDark)),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _pickRange,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 38),
              side: BorderSide(color: DiwaliColors.cardBorder.withValues(alpha: 0.8)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.expand_more_rounded, size: 16, color: DiwaliColors.purpleDark),
              const SizedBox(width: 6),
              Text(context.tr('wr_last_days').replaceAll('%1', '$_days'),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: DiwaliColors.purpleDark)),
            ]),
          ),
        ]),
        if (_refunds.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            context.tr('wr_summary').replaceAll('%1', '${_refunds.length}').replaceAll('%2', '$_totalRefunded'),
            style: const TextStyle(color: DiwaliColors.textDim, fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        if (_refundsLoading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator()))
        else if (_refunds.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Column(children: [
              const Icon(Icons.replay_rounded, size: 44, color: DiwaliColors.textDim),
              const SizedBox(height: 12),
              Text(context.tr('wr_empty_title'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: DiwaliColors.purpleDark)),
              const SizedBox(height: 6),
              Text(context.tr('wr_empty_sub'),
                  textAlign: TextAlign.center, style: const TextStyle(color: DiwaliColors.textDim, fontSize: 12.5, height: 1.4)),
            ]),
          )
        else
          ..._refunds.map(_refundTile),
      ],
    );
  }

  Widget _refundTile(Map<String, dynamic> r) {
    final diamonds = (r['diamondsRefunded'] as num?)?.toInt() ?? 0;
    final title = (r['title'] ?? '').toString();
    final reason = (r['reason'] ?? '').toString();
    final platform = (r['platform'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.green.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: const Icon(Icons.replay_rounded, color: AppColors.green, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              diamonds > 0 ? context.tr('diamonds_auto_refunded').replaceAll('%d', '$diamonds') : context.tr('wr_free_upload_refunded'),
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.green, fontSize: 13.5),
            ),
            if (title.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: DiwaliColors.purpleDark)),
            ],
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(context.tr('wr_reason').replaceAll('%1', reason),
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: DiwaliColors.textDim, fontSize: 12)),
            ],
            const SizedBox(height: 4),
            Text([_formatDate(r['refundedAt']), if (platform.isNotEmpty) platform].join('  ·  '),
                style: const TextStyle(color: DiwaliColors.textDim, fontSize: 11.5)),
          ]),
        ),
      ]),
    );
  }

  // ---------------- Transactions / Purchases ----------------
  Widget _buildList(BuildContext context, List list) {
    if (list.isEmpty) return EmptyView(message: context.tr('no_transactions_yet'), icon: Icons.receipt_long_outlined);
    return Column(
      children: list.map<Widget>((t) {
        final isSpend = t['type'] == 'diamond_spend';
        final isRefund = t['type'] == 'diamond_refund';
        final isSub = t['type'] == 'subscription_charge';
        final label = isSub
            ? 'Subscription payment (₹${t['amountINR']})'
            : t['type'] == 'diamond_purchase'
                ? context.tr('diamond_pack_label').replaceAll('%s', '${t['diamondPackage']}')
                : (isSpend ? context.tr('video_scheduled_label') : context.tr('diamond_refund_label'));
        final amount = isSub && (t['diamondPackage'] ?? 0) == 0
            ? '+${t['uploadsGranted'] ?? 0} uploads'
            : (t['type'] == 'diamond_purchase' || isSub)
            ? '+${t['diamondPackage']}'
            : (isSpend ? '-${t['diamondsForSpend']}' : '+${t['diamondsForSpend']}');
        final (color, statusLabel) = _statusBadge(context, t['status'] ?? '');
        final (icon, iconColor) = _txnIcon(t, isSpend);
        final refundNote = (t['adminNote'] ?? '').toString();
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: isRefund ? AppColors.green.withValues(alpha: 0.5) : DiwaliColors.cardBorder.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: DiwaliColors.purpleDark)),
                  const SizedBox(height: 4),
                  Text(formatDateTime(t['createdAt']), style: const TextStyle(color: DiwaliColors.textDim, fontSize: 12)),
                  if (isRefund && refundNote.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(refundNote, style: const TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(amount, style: TextStyle(fontWeight: FontWeight.w700, color: isSpend ? AppColors.red : AppColors.green)),
                const SizedBox(height: 4),
                isRefund
                    ? AppBadge(label: context.tr('auto_refunded_badge'), color: AppColors.green)
                    : AppBadge(label: statusLabel, color: color),
              ]),
            ],
          ),
        );
      }).toList(),
    );
  }
}
