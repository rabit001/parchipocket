part of '../shop_screens.dart';

class PrinterSettingsScreen extends StatelessWidget {
  const PrinterSettingsScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(
      state: state,
      title: 'Printer & devices',
      backTo: state.role == UserRole.streetVendor
          ? 'vendorProfile'
          : 'shopSettings',
      body: ListView(children: <Widget>[
        const SizedBox(height: 12),
        const Center(
            child: CircleAvatar(
                radius: 48,
                backgroundColor: PpColors.soft,
                child: Icon(Icons.print_outlined,
                    color: PpColors.forest, size: 42))),
        const SizedBox(height: 16),
        const Text('Thermal receipt printer',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 7),
        const Text(
            'Pair a compatible Bluetooth thermal printer in the real app to print small receipts.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: PpColors.secondary, height: 1.4)),
        const SizedBox(height: 20),
        const PpCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
              Text('Printer status',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              SizedBox(height: 9),
              Row(children: <Widget>[
                Icon(Icons.bluetooth_disabled, color: PpColors.secondary),
                SizedBox(width: 8),
                Expanded(
                    child: Text('No printer connected',
                        style:
                            TextStyle(fontSize: 12, color: PpColors.secondary)))
              ]),
              SizedBox(height: 8),
              Text(
                  'Bluetooth discovery and actual print commands need platform integration.',
                  style: TextStyle(fontSize: 10, color: PpColors.secondary))
            ])),
        const SizedBox(height: 15),
        PpPrimaryButton('Find nearby printers (Demo)',
            icon: Icons.bluetooth_searching,
            onPressed: () => state.go('printerTest')),
        const SizedBox(height: 9),
        PpSecondaryButton('Print test receipt preview',
            icon: Icons.receipt_long_outlined,
            onPressed: () => state.go('printerTest')),
        const SizedBox(height: 14),
        const PpDemoNotice(
            message:
                'No Bluetooth device is accessed. This screen only previews the future setup flow.'),
      ]));
}

class PrinterTestScreen extends StatelessWidget {
  const PrinterTestScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(
      state: state,
      title: 'Test receipt preview',
      backTo: 'printerSettings',
      body: ListView(children: <Widget>[
        const SizedBox(height: 6),
        const Text('Printer setup · Demo only',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                color: PpColors.secondary,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 15),
        PpCard(
            padding: const EdgeInsets.all(18),
            child: Column(children: <Widget>[
              const Text('PARCHIPOCKET',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 6),
              Text(state.activeStoreName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              const Text('SAMPLE TEST RECEIPT',
                  style: TextStyle(fontSize: 10, color: PpColors.secondary)),
              const Divider(height: 26),
              const Row(children: <Widget>[
                Expanded(
                    child:
                        Text('Printer test', style: TextStyle(fontSize: 11))),
                Text('₹0.00', style: TextStyle(fontSize: 11))
              ]),
              const Divider(height: 25),
              const Row(children: <Widget>[
                Expanded(
                    child: Text('TOTAL',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 12))),
                Text('₹0.00',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: PpColors.forest,
                        fontSize: 13))
              ]),
              const SizedBox(height: 18),
              const Text('This is a preview, not a real print.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: PpColors.secondary)),
            ])),
        const SizedBox(height: 14),
        const PpDemoNotice(
            message:
                'No physical printer was contacted. Real Bluetooth printing must be implemented and tested on compatible devices.'),
        const SizedBox(height: 18),
        PpPrimaryButton('Back to Printer Settings',
            onPressed: () => state.go('printerSettings')),
        const SizedBox(height: 9),
        PpSecondaryButton('Back to dashboard',
            onPressed: () => state.go(state.role == UserRole.streetVendor
                ? 'vendorHome'
                : 'shopHome')),
      ]));
}
