part of '../auth_screens.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(
        state: state,
        title: 'Welcome to ParchiPocket',
        showBack: true,
        backTo: 'splash',
        body: ListView(children: <Widget>[
          const SizedBox(height: 28),
          const Center(
              child: CircleAvatar(
                  radius: 30,
                  backgroundColor: PpColors.forest,
                  child: Text('P',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800)))),
          const SizedBox(height: 15),
          const Text('Your daily spending, in one place.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 28),
          PpSecondaryButton('Continue with Google (Demo)',
              icon: Icons.account_circle_outlined,
              onPressed: () => unawaited(state.enterDemoMode())),
          const SizedBox(height: 12),
          PpPrimaryButton('Continue with Phone Number',
              icon: Icons.phone_android, onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              final started = await state.beginAuthentication();
              if (!context.mounted) return;
              if (started) {
                state.go('phoneLogin');
              } else {
                messenger.showSnackBar(SnackBar(
                  content: Text(state.signOutError ??
                      'Could not start sign-in. Please retry.'),
                ));
              }
            } catch (error) {
              if (context.mounted) {
                messenger.showSnackBar(
                    SnackBar(content: Text('Could not start sign-in: $error')));
              }
            }
          }),
          const SizedBox(height: 16),
          const PpDemoNotice(
              message:
                  'Phone authentication uses Firebase Authentication. Google sign-in is simulated for this prototype.'),
          const SizedBox(height: 22),
          TextButton(
              onPressed: () => unawaited(state.enterDemoMode()),
              child: const Text('Skip sign-in and explore demo')),
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
    final buttonText =
        cooldown > 0 ? 'Send OTP (Wait ${cooldown}s)' : 'Send OTP';

    return PpScaffold(
      state: widget.state,
      title: 'Continue with phone',
      backTo: 'login',
      body: ListView(
        children: <Widget>[
          const SizedBox(height: 8),
          const Text(
            'Enter your mobile number to keep your household spending history safe and accessible.',
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
    final resendText = cooldown > 0
        ? 'Resend OTP (${cooldown}s)'
        : 'Didn\'t receive code? Resend OTP';

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
            PpPrimaryButton('Verify & Continue',
                icon: Icons.check_circle_outline, onPressed: _verifyCode),
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
