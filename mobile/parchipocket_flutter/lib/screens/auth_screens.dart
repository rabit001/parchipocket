import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/ui.dart';

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
          PpSecondaryButton('Continue with Google (Demo)', icon: Icons.account_circle_outlined, onPressed: () => state.go('roleSelection')),
          const SizedBox(height: 12),
          PpPrimaryButton('Continue with Phone Number', icon: Icons.phone_android, onPressed: () => state.go('phoneLogin')),
          const SizedBox(height: 16),
          const PpDemoNotice(message: 'Phone authentication uses Firebase Authentication. Google sign-in is simulated for this prototype.'),
          const SizedBox(height: 22),
          TextButton(onPressed: () => state.go('roleSelection'), child: const Text('Skip sign-in and explore demo')),
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
            PpPrimaryButton('Send OTP', icon: Icons.sms_outlined, onPressed: _sendOtp),
          const SizedBox(height: 18),
          const PpDemoNotice(
            message:
                'Firebase Phone Auth enabled. Enter your 10-digit phone number or use configured Firebase Console test numbers.',
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
                onPressed: _resendCode,
                child: const Text('Didn\'t receive code? Resend OTP'),
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
  Widget build(BuildContext context) => PpScaffold(state: state, title: 'Choose account type', backTo: 'login', body: ListView(children: <Widget>[
        const SizedBox(height: 5),
        const Text('How will you use ParchiPocket?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 7),
        const Text('Choose the experience that fits your everyday needs.', style: TextStyle(fontSize: 12, color: PpColors.secondary)),
        const SizedBox(height: 22),
        _RoleCard(title: 'Customer', detail: 'Save bills and track spending', icon: Icons.receipt_long_outlined, onTap: () => state.setRole(UserRole.customer)),
        const SizedBox(height: 12),
        _RoleCard(title: 'Shop Owner', detail: 'Create receipts, record expenses and manage udhaar', icon: Icons.storefront_outlined, onTap: () => state.setRole(UserRole.shopOwner)),
        const SizedBox(height: 12),
        _RoleCard(title: 'Street Vendor', detail: 'Quick billing with minimal setup', icon: Icons.shopping_basket_outlined, onTap: () => state.setRole(UserRole.streetVendor)),
        const SizedBox(height: 14),
        const PpDemoNotice(message: 'This role selection controls the local prototype. It does not create a real user account.'),
      ]));
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
  @override
  void dispose() { name.dispose(); email.dispose(); super.dispose(); }
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
        const PpDemoNotice(message: 'A seller should link a receipt to your account only with verified details and your permission.'),
        const SizedBox(height: 20),
        PpPrimaryButton('Save & Continue', onPressed: () {
          widget.state.updateProfile(name: name.text, email: email.text, location: widget.state.city);
          widget.state.go('customerHome');
        }),
      ]));
}

class ShopSetupScreen extends StatefulWidget {
  const ShopSetupScreen({super.key, required this.state});
  final AppState state;
  @override
  State<ShopSetupScreen> createState() => _ShopSetupScreenState();
}
class _ShopSetupScreenState extends State<ShopSetupScreen> {
  late final TextEditingController name = TextEditingController(text: widget.state.shopName);
  late final TextEditingController address = TextEditingController(text: widget.state.shopAddress);
  String category = 'Kirana';
  @override
  void dispose() { name.dispose(); address.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => PpScaffold(state: widget.state, title: 'Register your shop', backTo: 'roleSelection', body: ListView(children: <Widget>[
        const Text('Set up billing for your business.', style: TextStyle(fontSize: 13, color: PpColors.secondary)),
        const SizedBox(height: 20),
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
        PpPrimaryButton('Create Shop Profile', onPressed: () => widget.state.updateShop(name: name.text, category: category, address: address.text)),
      ]));
}

class VendorSetupScreen extends StatefulWidget {
  const VendorSetupScreen({super.key, required this.state});
  final AppState state;
  @override
  State<VendorSetupScreen> createState() => _VendorSetupScreenState();
}
class _VendorSetupScreenState extends State<VendorSetupScreen> {
  late final TextEditingController name = TextEditingController(text: widget.state.vendorName);
  String category = 'Tea / Snacks';
  @override
  void dispose() { name.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => PpScaffold(state: widget.state, title: 'Quick setup', backTo: 'roleSelection', body: ListView(children: <Widget>[
        const Text('Start billing without creating a product catalogue.', style: TextStyle(fontSize: 13, color: PpColors.secondary)),
        const SizedBox(height: 22),
        PpField(label: 'Vendor or stall name', controller: name, hint: 'e.g. Raju Tea Stall'),
        const SizedBox(height: 15),
        const Text('What do you usually sell?', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: PpColors.secondary)),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(initialValue: category, items: const <String>['Tea / Snacks', 'Vegetables', 'Street food', 'Other'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => category = v ?? 'Other')),
        const SizedBox(height: 20),
        const PpDemoNotice(message: 'Quick mode keeps setup minimal. Item entry, saving and receipt generation are local demo flows.'),
        const SizedBox(height: 20),
        PpPrimaryButton('Start Quick Billing', onPressed: () => widget.state.updateVendor(name: name.text, category: category)),
        const SizedBox(height: 10),
        PpSecondaryButton('Skip for now', onPressed: () => widget.state.go('vendorHome')),
      ]));
}
