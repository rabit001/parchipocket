import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class ReceiptClaimIssueScreen extends StatefulWidget {
  const ReceiptClaimIssueScreen({super.key, required this.state});
  final AppState state;

  @override
  State<ReceiptClaimIssueScreen> createState() =>
      _ReceiptClaimIssueScreenState();
}

class _ReceiptClaimIssueScreenState extends State<ReceiptClaimIssueScreen> {
  late String _code = widget.state.newReceiptClaimCode();
  bool _issued = false;
  bool _submitting = false;
  String? _issueError;

  Future<void> _issue() async {
    final bill = widget.state.selectedBill;
    if (bill == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.state.issueReceiptClaim(bill, _code);
      if (!mounted) return;
      setState(() {
        _issued = true;
        _issueError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Claim code created. Share it with the customer now.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _issueError = error.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create claim code: $error')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.state.selectedBill;
    return PpScaffold(
      state: widget.state,
      title: 'Share receipt securely',
      backTo: 'billDetail',
      body: bill == null
          ? const PpEmptyState(
              icon: Icons.receipt_long,
              title: 'No bill selected',
              message: 'Open a bill before issuing a claim code.')
          : ListView(children: <Widget>[
              Text(
                'Create a one-time claim code for ${bill.displayNumber}. The code expires within 24 hours and can be used by one customer account.',
                  style: const TextStyle(
                      fontSize: 12, color: PpColors.secondary, height: 1.5)),
              const SizedBox(height: 20),
              if (_issued) ...<Widget>[
                Center(
                    child: QrImageView(
                        data: _code, size: 220, backgroundColor: Colors.white)),
                const SizedBox(height: 12),
                SelectableText(_code,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                const PpDemoNotice(
                    message:
                        'The raw code is shown only now. If it is lost, generate a new code; the previous code remains usable until claimed or expired.'),
                const SizedBox(height: 12),
                PpSecondaryButton('Generate another code',
                    icon: Icons.refresh,
                    onPressed: _submitting
                        ? null
                        : () => setState(() {
                              _code = widget.state.newReceiptClaimCode();
                              _issued = false;
                            })),
              ] else ...<Widget>[
                const Center(
                    child: Icon(Icons.lock_outline,
                        color: PpColors.forest, size: 72)),
                const SizedBox(height: 8),
                if (_issueError != null) ...<Widget>[
                  Text(_issueError!, style: const TextStyle(color: PpColors.error, fontSize: 12)),
                  const SizedBox(height: 8),
                ],
                PpPrimaryButton(
                    _submitting ? 'Creating code…' : 'Create / retry this code',
                    icon: Icons.qr_code_2,
                    onPressed: _submitting ? null : _issue),
                if (_issueError != null) ...<Widget>[
                  const SizedBox(height: 8),
                  PpSecondaryButton('Generate a fresh code', icon: Icons.refresh, onPressed: _submitting ? null : () => setState(() { _code = widget.state.newReceiptClaimCode(); _issueError = null; })),
                ],
                const SizedBox(height: 10),
                const PpDemoNotice(
                    message:
                        'The code is generated from secure random bytes and only its SHA-256 digest is saved. Keep this screen open until you share the code.'),
              ],
            ]),
    );
  }
}
