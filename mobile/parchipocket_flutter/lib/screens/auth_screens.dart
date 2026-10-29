import 'dart:async';

import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class AuthSessionLoadingScreen extends StatelessWidget {
  const AuthSessionLoadingScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Checking your account…'),
              ],
            ),
          ),
        ),
      );
}

class ProfileLoadErrorScreen extends StatelessWidget {
  const ProfileLoadErrorScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.cloud_off_outlined, size: 42, color: PpColors.error),
                  const SizedBox(height: 14),
                  const Text(
                    'Could not verify your account',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.cloudError ?? 'Check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: PpColors.secondary),
                  ),
                  const SizedBox(height: 20),
                  PpPrimaryButton(
                    'Retry',
                    onPressed: state.isCloudLoading ? null : () => state.retryProfileLoad(),
                  ),
                  const SizedBox(height: 8),
                  PpSecondaryButton('Log Out', onPressed: () => state.go('logout')),
                ],
              ),
            ),
          ),
        ),
      );
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: Center(child: Padding(padding: const EdgeInsets.all(26), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
          Container(width: 76, height: 76, decoration: const BoxDecoration(color: PpColors.forest, shape: BoxShape.circle), child: const Center(child: Text('P', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)))),
          const SizedBox(height: 16),
          const Text('ParchiPocket', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: PpColors.ink)),
          const SizedBox(height: 10),
          const Text('Every small purchase, properly recorded.', textAlign: TextAlign.center, style: TextStyle(color: PpColors.secondary, fontSize: 14)),
          const SizedBox(height: 8),
          const Text('Bills for customers. Clear records for sellers.', textAlign: TextAlign.center, style: TextStyle(color: PpColors.secondary, fontSize: 12)),
          const SizedBox(height: 42),
          PpPrimaryButton('Get Started', onPressed: () => state.go('login')),
        ])))),
      );
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(
        state: state, title: 'Welcome to ParchiPocket', showBack: true, backTo: 'splash',
        body: ListView(children: <Widget>[
          const SizedBox(height: 28),
          const Center(child: CircleAvatar(radius: 30, backgroundColor: PpColors.forest, child: Text('P', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)))),
          const SizedBox(height: 15),
          const Text('Your everyday bills, in one place.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 28),
          PpSecondaryButton('Continue with Google (Demo)', icon: Icons.account_circle_outlined, onPressed: () => unawaited(state.enterDemoMode())),
          const SizedBox(height: 12),
          PpPrimaryButton('Continue with Phone Number', icon: Icons.phone_android, onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              final started = await state.beginAuthentication();
              if (!context.mounted) return;
              if (started) {
                state.go('phoneLogin');
              } else {
                messenger.showSnackBar(SnackBar(
                  content: Text(state.signOutError ?? 'Could not start sign-in. Please retry.'),
                ));
              }
            } catch (error) {
              if (context.mounted) {
                messenger.showSnackBar(SnackBar(content: Text('Could not start sign-in: $error')));
              }
            }
          }),
          const SizedBox(height: 16),
          const PpDemoNotice(message: 'Phone authentication uses Firebase Authentication. Google sign-in is simulated for this prototype.'),
          const SizedBox(height: 22),
          TextButton(onPressed: () => unawaited(state.enterDemoMode()), child: const Text('Skip sign-in and explore demo')),
        ]),
      );
}

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key, required this.state});
  final AppState state;
  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final TextEditingController phone = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.state.phoneNumber.isNotEmpty) {
      phone.text = widget.state.phoneNumber.startsWith('+91')
          ? widget.state.phoneNumber.substring(3)
          : widget.state.phoneNumber;
    }
  }

  @override
  void dispose() {
    phone.dispose();
    super.dispose();
  }

  void _sendOtp() {
    FocusScope.of(context).unfocus();
    widget.state.sendPhoneOtp(
      rawPhone: phone.text,
      onSuccessCodeSent: () {
        if (mounted) {
          widget.state.go('verifyOtp');
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red[800]),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.state.isPhoneAuthLoading;
    final errorMessage = widget.state.phoneAuthError;
    final cooldown = widget.state.otpCooldownSecondsRemaining;
    final buttonText = cooldown > 0 ? 'Send OTP (Wait ${cooldown}s)' : 'Send OTP';

    return PpScaffold(
      state: widget.state,
      title: 'Continue with phone',
      backTo: 'login',
      body: ListView(
        children: <Widget>[
          const SizedBox(height: 8),
          const Text(
            'Enter your mobile number to keep your bills safe and accessible.',
            style: TextStyle(fontSize: 13, color: PpColors.secondary),
          ),
          const SizedBox(height: 24),
          PpField(
            label: 'Mobile number',
            controller: phone,
            hint: 'e.g. 9876543210 or +919876543210',
            keyboardType: TextInputType.phone,
            readOnly: isLoading,
          ),
          const SizedBox(height: 18),
          if (errorMessage != null && errorMessage.isNotEmpty) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                errorMessage,
                style: TextStyle(color: Colors.red.shade800, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              ),
            )
          else
            PpPrimaryButton(
              buttonText,
              icon: Icons.sms_outlined,
              onPressed: cooldown > 0 ? null : _sendOtp,
            ),
          const SizedBox(height: 18),
          const PpDemoNotice(
            message:
                'Firebase Phone Auth enabled with 60s cooldown protection. Enter your 10-digit phone number or use configured Firebase Console test numbers.',
          ),
        ],
      ),
    );
  }
}

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.state});
  final AppState state;
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController code = TextEditingController();

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  void _verifyCode() {
    FocusScope.of(context).unfocus();
    widget.state.verifySmsCode(
      smsCode: code.text,
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red[800]),
          );
        }
      },
    );
  }

  void _resendCode() {
    FocusScope.of(context).unfocus();
    widget.state.sendPhoneOtp(
      rawPhone: widget.state.phoneNumber,
      isResend: true,
      onSuccessCodeSent: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A new OTP code has been sent.')),
          );
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red[800]),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.state.isPhoneAuthLoading;
    final errorMessage = widget.state.phoneAuthError;
    final phoneDisplay = widget.state.phoneNumber.isEmpty
        ? 'your mobile number'
        : widget.state.phoneNumber;
    final cooldown = widget.state.otpCooldownSecondsRemaining;
    final resendText = cooldown > 0 ? 'Resend OTP (${cooldown}s)' : 'Didn\'t receive code? Resend OTP';

    return PpScaffold(
      state: widget.state,
      title: 'Verify number',
      backTo: 'phoneLogin',
      body: ListView(
        children: <Widget>[
          const SizedBox(height: 8),
          Text(
            'Enter the 6-digit code sent to $phoneDisplay.',
            style: const TextStyle(fontSize: 13, color: PpColors.secondary),
          ),
          const SizedBox(height: 24),
          PpField(
            label: 'One-time password',
            controller: code,
            hint: 'Enter 6-digit code',
            keyboardType: TextInputType.number,
            readOnly: isLoading,
          ),
          const SizedBox(height: 18),
          if (errorMessage != null && errorMessage.isNotEmpty) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                errorMessage,
                style: TextStyle(color: Colors.red.shade800, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              ),
            )
          else ...<Widget>[
            PpPrimaryButton('Verify & Continue', icon: Icons.check_circle_outline, onPressed: _verifyCode),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: cooldown > 0 ? null : _resendCode,
                child: Text(resendText),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => PpScaffold(
        state: state,
        title: 'Home & Family',
        backTo: 'login',
        body: ListView(children: <Widget>[
          const SizedBox(height: 5),
          const Text(
            'Track everyday spending',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          const Text(
            'Record household purchases, by voice or manually, and see where your money goes.',
            style: TextStyle(fontSize: 12, color: PpColors.secondary),
          ),
          const SizedBox(height: 22),
          _RoleCard(
            title: 'Home & Family',
            detail: 'Daily purchases, spending history and monthly insights',
            icon: Icons.wallet_outlined,
            onTap: () => state.setRole(UserRole.customer),
          ),
        ]),
      );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.title, required this.detail, required this.icon, required this.onTap});
  final String title, detail;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(child: InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap, child: Padding(padding: const EdgeInsets.all(16), child: Row(children: <Widget>[
        Container(width: 48, height: 48, decoration: BoxDecoration(color: PpColors.soft, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: PpColors.forest, size: 24)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text(detail, style: const TextStyle(fontSize: 11, color: PpColors.secondary, height: 1.35))])),
        const Icon(Icons.chevron_right, color: PpColors.forest),
      ]))));
}

class CustomerSetupScreen extends StatefulWidget {
  const CustomerSetupScreen({super.key, required this.state});
  final AppState state;
  @override
  State<CustomerSetupScreen> createState() => _CustomerSetupScreenState();
}
class _CustomerSetupScreenState extends State<CustomerSetupScreen> {
  late final TextEditingController name = TextEditingController(text: widget.state.customerName);
  late final TextEditingController email = TextEditingController(text: widget.state.customerEmail);
  bool _isSubmitting = false;

  @override
  void dispose() { name.dispose(); email.dispose(); super.dispose(); }

  Future<void> _saveProfile() async {
    if (_isSubmitting) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSubmitting = true);
    try {
      final success = await widget.state.updateProfile(
        name: name.text,
        email: email.text,
        location: widget.state.city,
        successPage: null,
      );
      if (!mounted) return;
      if (success) {
        final message = widget.state.isDemoMode
            ? 'Profile saved in local demo mode.'
            : 'Profile saved to your account.';
        messenger.showSnackBar(SnackBar(content: Text(message)));
        widget.state.go('customerHome');
      } else {
        final error = widget.state.cloudError ?? 'Profile was not saved. Please retry.';
        messenger.showSnackBar(SnackBar(content: Text(error)));
      }
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Profile was not saved. Check your connection and retry. ($error)')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PpScaffold(state: widget.state, title: 'Set up your profile', backTo: 'roleSelection', body: ListView(children: <Widget>[
        const SizedBox(height: 10),
        const Center(child: CircleAvatar(radius: 34, backgroundColor: PpColors.soft, child: Text('RM', style: TextStyle(fontWeight: FontWeight.w800, color: PpColors.forest, fontSize: 20)))),
        const SizedBox(height: 12),
        const Text('Add a profile photo (optional)', textAlign: TextAlign.center, style: TextStyle(color: PpColors.forest, fontWeight: FontWeight.w700, fontSize: 11)),
        const SizedBox(height: 25),
        PpField(label: 'Full name', controller: name, hint: 'Enter your name'),
        const SizedBox(height: 15),
        const Text('Verified phone number', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: PpColors.secondary)),
        const SizedBox(height: 7),
        TextField(
          readOnly: true,
          decoration: InputDecoration(
            hintText: widget.state.phoneNumber.isNotEmpty
                ? widget.state.phoneNumber
                : '+91 Verified Number',
          ),
        ),
        const SizedBox(height: 15),
        PpField(label: 'Email (optional)', controller: email, hint: 'name@example.com', keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 18),
        const PpDemoNotice(message: 'Your household spending is saved under your own account. Review each entry before saving it.'),
        const SizedBox(height: 20),
        PpPrimaryButton(
          _isSubmitting ? 'Saving…' : 'Save & Continue',
          onPressed: _isSubmitting ? null : _saveProfile,
        ),
      ]));
}

class ShopSetupScreen extends StatefulWidget {
  const ShopSetupScreen({super.key, required this.state});
  final AppState state;
  @override
  State<ShopSetupScreen> createState() => _ShopSetupScreenState();
}
class _ShopSetupScreenState extends State<ShopSetupScreen> {
  late final TextEditingController contactName = TextEditingController(text: widget.state.customerName);
  late final TextEditingController name = TextEditingController(text: widget.state.shopName);
  late final TextEditingController address = TextEditingController(text: widget.state.shopAddress);
  String category = 'Kirana';
  String? _contactNameError;
  bool _isSubmitting = false;

  @override
  void dispose() { contactName.dispose(); name.dispose(); address.dispose(); super.dispose(); }

  Future<void> _saveShop() async {
    if (_isSubmitting) return;
    if (contactName.text.trim().isEmpty) {
      setState(() => _contactNameError = 'Enter the owner/contact full name to continue.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _contactNameError = null;
      _isSubmitting = true;
    });
    try {
      final success = await widget.state.updateShop(
        ownerName: contactName.text,
        name: name.text,
        category: category,
        address: address.text,
      );
      if (!mounted) return;
      if (success) {
        final message = widget.state.isDemoMode
            ? 'Shop profile saved in local demo mode.'
            : 'Shop profile saved to your account.';
        messenger.showSnackBar(SnackBar(content: Text(message)));
        widget.state.go('shopHome');
      } else {
        final error = widget.state.cloudError ?? 'Shop profile was not saved. Please retry.';
        messenger.showSnackBar(SnackBar(content: Text(error)));
      }
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Shop profile was not saved. Check your connection and retry. ($error)')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PpScaffold(state: widget.state, title: 'Register your shop', backTo: 'roleSelection', body: ListView(children: <Widget>[
        const Text('Set up billing for your business.', style: TextStyle(fontSize: 13, color: PpColors.secondary)),
        const SizedBox(height: 20),
        const Text('Owner/contact full name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: PpColors.secondary)),
        const SizedBox(height: 7),
        TextField(
          controller: contactName,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) {
            if (_contactNameError != null) {
              setState(() => _contactNameError = null);
            }
          },
          decoration: const InputDecoration(hintText: 'Enter your full name'),
        ),
        if (_contactNameError != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(_contactNameError!, style: const TextStyle(color: PpColors.error, fontSize: 12)),
        ],
        const SizedBox(height: 15),
        PpField(label: 'Shop name', controller: name, hint: 'e.g. Sharma Kirana Store'),
        const SizedBox(height: 15),
        const Text('Shop category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: PpColors.secondary)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(initialValue: category, items: const <String>['Kirana', 'General', 'Food', 'Other'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => category = v ?? 'Kirana')),
        const SizedBox(height: 15),
        PpField(label: 'Shop address', controller: address, hint: 'Street, area, city'),
        const SizedBox(height: 17),
        const PpDemoNotice(message: 'GSTIN and Bluetooth printer setup can be added later. This screen does not register a legal business.'),
        const SizedBox(height: 20),
        PpPrimaryButton(
          _isSubmitting ? 'Saving…' : 'Create Shop Profile',
          onPressed: _isSubmitting ? null : _saveShop,
        ),
      ]));
}

class VendorSetupScreen extends StatefulWidget {
  const VendorSetupScreen({super.key, required this.state});
  final AppState state;
  @override
  State<VendorSetupScreen> createState() => _VendorSetupScreenState();
}
class _VendorSetupScreenState extends State<VendorSetupScreen> {
  late final TextEditingController contactName = TextEditingController(text: widget.state.customerName);
  late final TextEditingController name = TextEditingController(text: widget.state.vendorName);
  String category = 'Tea / Snacks';
  String? _contactNameError;
  bool _isSubmitting = false;

  @override
  void dispose() { contactName.dispose(); name.dispose(); super.dispose(); }

  Future<void> _saveVendor() async {
    if (_isSubmitting) return;
    if (contactName.text.trim().isEmpty) {
      setState(() => _contactNameError = 'Enter the owner/contact full name to continue.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _contactNameError = null;
      _isSubmitting = true;
    });
    try {
      final success = await widget.state.updateVendor(
        ownerName: contactName.text,
        name: name.text,
        category: category,
      );
      if (!mounted) return;
      if (success) {
        final message = widget.state.isDemoMode
            ? 'Vendor profile saved in local demo mode.'
            : 'Vendor profile saved to your account.';
        messenger.showSnackBar(SnackBar(content: Text(message)));
        widget.state.go('vendorHome');
      } else {
        final error = widget.state.cloudError ?? 'Vendor profile was not saved. Please retry.';
        messenger.showSnackBar(SnackBar(content: Text(error)));
      }
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Vendor profile was not saved. Check your connection and retry. ($error)')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PpScaffold(state: widget.state, title: 'Quick setup', backTo: 'roleSelection', body: ListView(children: <Widget>[
        const Text('Start billing without creating a product catalogue.', style: TextStyle(fontSize: 13, color: PpColors.secondary)),
        const SizedBox(height: 22),
        const Text('Owner/contact full name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: PpColors.secondary)),
        const SizedBox(height: 7),
        TextField(
          controller: contactName,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) {
            if (_contactNameError != null) {
              setState(() => _contactNameError = null);
            }
          },
          decoration: const InputDecoration(hintText: 'Enter your full name'),
        ),
        if (_contactNameError != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(_contactNameError!, style: const TextStyle(color: PpColors.error, fontSize: 12)),
        ],
        const SizedBox(height: 15),
        PpField(label: 'Vendor or stall name', controller: name, hint: 'e.g. Raju Tea Stall'),
        const SizedBox(height: 15),
        const Text('What do you usually sell?', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: PpColors.secondary)),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(initialValue: category, items: const <String>['Tea / Snacks', 'Vegetables', 'Street food', 'Other'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => category = v ?? 'Other')),
        const SizedBox(height: 20),
        const PpDemoNotice(message: 'Quick mode keeps setup minimal. Item entry, saving and receipt generation are local demo flows.'),
        const SizedBox(height: 20),
        PpPrimaryButton(
          _isSubmitting ? 'Saving…' : 'Start Quick Billing',
          onPressed: _isSubmitting ? null : _saveVendor,
        ),
        const SizedBox(height: 10),
        PpSecondaryButton('Skip for now', onPressed: () => widget.state.go('vendorHome')),
      ]));
}
