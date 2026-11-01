part of '../common_screens.dart';

class ShareReceiptScreen extends StatelessWidget {
  const ShareReceiptScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final bill = state.selectedBill;
    return PpScaffold(
        state: state,
        title: 'Share receipt',
        backTo: bill == null ? 'customerHome' : 'billDetail',
        body: ListView(children: <Widget>[
          PpCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                Text((bill?.store ?? state.activeStoreName).toUpperCase(),
                    style: const TextStyle(
                        fontSize: 10,
                        color: PpColors.secondary,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                Text('Bill ${bill?.displayNumber ?? 'Sample'}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(
                    bill == null
                        ? 'Sample receipt preview'
                        : formatDateTime(bill.createdAt),
                    style: const TextStyle(
                        fontSize: 10, color: PpColors.secondary)),
                const SizedBox(height: 8),
                Align(
                    alignment: Alignment.centerRight,
                    child: Text(money(bill?.total ?? 0),
                        style: const TextStyle(
                            color: PpColors.forest,
                            fontSize: 22,
                            fontWeight: FontWeight.w800))),
              ])),
          const SizedBox(height: 18),
          const PpSectionTitle('Choose how to share'),
          const SizedBox(height: 9),
          PpPrimaryButton('Share via WhatsApp (Demo)',
              icon: Icons.chat_outlined, onPressed: () {
            state.lastNotice = 'WhatsApp share';
            state.go('sharePreview');
          }),
          const SizedBox(height: 10),
          PpSecondaryButton('Copy receipt link (Demo)', icon: Icons.link,
              onPressed: () {
            state.lastNotice = 'Copy receipt link';
            state.go('sharePreview');
          }),
          const SizedBox(height: 10),
          PpSecondaryButton('Download PDF (Demo)',
              icon: Icons.download_outlined, onPressed: () {
            state.lastNotice = 'PDF export';
            state.go('sharePreview');
          }),
          const SizedBox(height: 16),
          const PpDemoNotice(
              message:
                  'These options preview the workflow only. No WhatsApp window opens, no clipboard is changed, and no PDF is created.'),
        ]));
  }
}

class SharePreviewScreen extends StatelessWidget {
  const SharePreviewScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(
      state: state,
      title: 'Receipt action preview',
      backTo: 'shareReceipt',
      body: ListView(children: <Widget>[
        const SizedBox(height: 25),
        const Center(
            child: CircleAvatar(
                radius: 35,
                backgroundColor: PpColors.soft,
                child: Icon(Icons.receipt_long,
                    color: PpColors.forest, size: 36))),
        const SizedBox(height: 17),
        const Text('Receipt action ready',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text(state.lastNotice.isEmpty ? 'Share receipt' : state.lastNotice,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: PpColors.forest,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        const PpDemoNotice(
            message:
                'This prototype does not open external apps, copy links, or generate a PDF. Those platform actions will be wired into the Android app.'),
        const SizedBox(height: 22),
        PpPrimaryButton('Done', onPressed: () => state.go('shareReceipt')),
      ]));
}
