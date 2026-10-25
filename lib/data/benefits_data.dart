import 'package:flutter/material.dart';

/// "confirmed" = taken from official government sources.
/// "checkWithAsha" = only found on secondary sites, or sources disagree.
/// The app tells the user to confirm these with an ASHA / Anganwadi worker.
enum BenefitStatus { confirmed, checkWithAsha }

class BenefitScheme {
  final String id;
  final String title;
  final String summary;
  final IconData icon;
  final Color color;
  final List<String> whatYouGet;
  final String whoCanGet;
  final List<String> howToGet;
  final List<String> documents;
  final String? officialUrl;
  final String source;
  final String lastVerified;
  final BenefitStatus status;

  const BenefitScheme({
    required this.id,
    required this.title,
    required this.summary,
    required this.icon,
    required this.color,
    required this.whatYouGet,
    required this.whoCanGet,
    required this.howToGet,
    this.documents = const [],
    this.officialUrl,
    required this.source,
    required this.lastVerified,
    required this.status,
  });
}

// Category colours (deliberately NOT green/orange/red, which mean risk level):
// blue = check-ups, rose = hospital care, purple = money, teal = food.
const _blue = Color(0xFF3B6FD4);
const _rose = Color(0xFFE85D75);
const _purple = Color(0xFF7B5EA7);
const _teal = Color(0xFF0D9488);

const String _checked = 'Checked 22 Oct 2026';

const List<BenefitScheme> kBenefitSchemes = [
  // ---------- CONFIRMED (official sources) ----------
  BenefitScheme(
    id: 'pmsma',
    title: 'Free check-up every month',
    summary: 'Free doctor check-up on the 9th of every month',
    icon: Icons.medical_services_outlined,
    color: _blue,
    whatYouGet: [
      'Free check-up by a doctor',
      'Free tests and medicines in the check-up package',
      'More follow-up visits if your pregnancy needs close watching',
    ],
    whoCanGet:
        'Pregnant women in the second or third part of pregnancy, at government health centres and hospitals.',
    howToGet: [
      'Go to a government health centre or hospital on the 9th',
      'If the 9th is a Sunday or holiday, go on the next working day',
      'Ask your ASHA which centre near you holds the clinic',
    ],
    documents: ['Mother and Child Protection (MCP) card, if you have one'],
    officialUrl: 'https://pmsma.mohfw.gov.in/about-scheme/',
    source: 'Ministry of Health & Family Welfare (PMSMA)',
    lastVerified: _checked,
    status: BenefitStatus.confirmed,
  ),
  BenefitScheme(
    id: 'jssk',
    title: 'Free delivery in a government hospital',
    summary: 'No cost for delivery, medicines, tests, food and transport',
    icon: Icons.local_hospital_outlined,
    color: _rose,
    whatYouGet: [
      'Free normal delivery and free C-section',
      'Free medicines and tests',
      'Free blood if needed',
      'Free food in hospital: 3 days after normal delivery, 7 days after C-section',
      'Free transport from home to hospital, and back home',
    ],
    whoCanGet:
        'Every pregnant woman who delivers in a government health facility.',
    howToGet: [
      'Register your pregnancy with your ASHA or nearest government health centre',
      'Plan to deliver in a government hospital',
      'Ask your ASHA how to get the free transport',
    ],
    officialUrl:
        'https://nhm.gov.in/index1.php?lang=1&level=3&sublinkid=842&lid=308',
    source: 'National Health Mission (Janani Shishu Suraksha Karyakram)',
    lastVerified: _checked,
    status: BenefitStatus.confirmed,
  ),
  BenefitScheme(
    id: 'mathru_poorna',
    title: 'Free hot meal at Anganwadi',
    summary: 'One full meal at the Anganwadi, from pregnancy until 6 months after delivery',
    icon: Icons.restaurant_outlined,
    color: _teal,
    whatYouGet: [
      'Rice, dal with vegetables or sambar',
      'A boiled egg (sprouts if you do not eat eggs)',
      'Milk',
      'Iron tablets and weight check',
    ],
    whoCanGet:
        'Pregnant women and breastfeeding mothers. Ask your Anganwadi worker to register you.',
    howToGet: [
      'Meet your Anganwadi worker and register',
      'Go to the Anganwadi at meal time',
      'Ask if the hot meal is running at your Anganwadi. In some places food packets are given instead',
    ],
    officialUrl:
        'https://dwcd.karnataka.gov.in/info-2/INTEGRATED+CHILD+DEVELOPMENT+SERVICES+SCHEME/en',
    source: 'Karnataka Dept. of Women & Child Development (Mathru Poorna)',
    lastVerified: _checked,
    status: BenefitStatus.confirmed,
  ),
  BenefitScheme(
    id: 'thr',
    title: 'Free food packets',
    summary: 'Take-home nutrition packets from the Anganwadi',
    icon: Icons.inventory_2_outlined,
    color: _teal,
    whatYouGet: [
      'Packets of nutritious food for pregnant women and new mothers',
      'Extra energy and protein every day',
    ],
    whoCanGet:
        'Pregnant women and breastfeeding mothers. This is a legal right under the National Food Security Act.',
    howToGet: [
      'Register with your Anganwadi worker',
      'Collect your packets at the Anganwadi',
    ],
    source: 'National Food Security Act 2013; Ministry of Women & Child Development',
    lastVerified: _checked,
    status: BenefitStatus.confirmed,
  ),

  // ---------- CHECK WITH ASHA (not confirmed from official sources) ----------
  BenefitScheme(
    id: 'jsy',
    title: 'Cash for hospital delivery',
    summary: 'Cash help when you deliver in a government hospital',
    icon: Icons.payments_outlined,
    color: _purple,
    whatYouGet: [
      '₹700 if you live in a village (rural area)',
      '₹600 if you live in a town or city (urban area)',
      'Paid into your bank account after delivery',
    ],
    whoCanGet:
        'Mostly for BPL, SC and ST women who deliver in a government hospital. Sources differ, so ask your ASHA if you qualify.',
    howToGet: [
      'Tell your ASHA early in your pregnancy',
      'Deliver in a government hospital',
      'There is usually no separate form. Your ASHA helps you',
    ],
    documents: [
      'Aadhaar card',
      'Bank account details',
      'BPL card or SC/ST certificate, if you have one',
    ],
    source: 'Karnataka government institute page and National Health Mission (Janani Suraksha Yojana)',
    lastVerified: _checked,
    status: BenefitStatus.checkWithAsha,
  ),
  BenefitScheme(
    id: 'pmmvy',
    title: 'Money for you and your baby',
    summary: '₹5,000 for the first child, ₹6,000 for a second girl child',
    icon: Icons.savings_outlined,
    color: _purple,
    whatYouGet: [
      '₹5,000 for your first living child',
      '₹6,000 if your second child is a girl',
      'Paid into your bank account in parts, after check-ups and baby registration',
    ],
    whoCanGet:
        'Pregnant and breastfeeding women. Government employees are not eligible. Ask your ASHA if you qualify.',
    howToGet: [
      'Ask your ASHA or Anganwadi worker to register you',
      'Or register on the PMMVY website or app',
      'Ask your ASHA for the exact steps and dates for each payment',
    ],
    documents: [
      'Aadhaar card',
      'Mobile number',
      'Bank account',
      'Proof such as ration card, income certificate or MGNREGA job card',
    ],
    officialUrl: 'https://pmmvy.wcd.gov.in/',
    source: 'PMMVY portal (details from secondary websites. Please confirm)',
    lastVerified: _checked,
    status: BenefitStatus.checkWithAsha,
  ),
  BenefitScheme(
    id: 'prasoothi_araike',
    title: 'Prasoothi Araike',
    summary: 'Money support in two parts for Karnataka mothers',
    icon: Icons.account_balance_wallet_outlined,
    color: _purple,
    whatYouGet: [
      'Money support, paid in two parts',
      'The second part is paid when your baby is born in a government hospital',
      'Ask your ASHA for the current amount',
    ],
    whoCanGet: 'Women from BPL, SC or ST families in Karnataka.',
    howToGet: [
      'Contact your ANM or ASHA',
      'Deliver in a government hospital for the second part',
    ],
    source: 'Karnataka scheme listings (secondary websites. Please confirm)',
    lastVerified: _checked,
    status: BenefitStatus.checkWithAsha,
  ),
  BenefitScheme(
    id: 'thayi_bhagya',
    title: 'Free delivery in a private hospital',
    summary: 'Cashless delivery in a registered private hospital',
    icon: Icons.local_hospital_outlined,
    color: _rose,
    whatYouGet: [
      'Free delivery at a registered private hospital',
      'No payment from admission to discharge',
    ],
    whoCanGet: 'Pregnant women from BPL families in Karnataka.',
    howToGet: [
      'Register with the Junior Female Health Assistant in your area',
      'Find a registered private hospital near you',
      'Show your ANC card at the hospital',
    ],
    documents: ['ANC card'],
    source: 'Karnataka scheme listings (secondary website. Please confirm)',
    lastVerified: _checked,
    status: BenefitStatus.checkWithAsha,
  ),
  BenefitScheme(
    id: 'madilu',
    title: 'Madilu kit',
    summary: 'A free kit of mother and baby items after delivery',
    icon: Icons.card_giftcard,
    color: _rose,
    whatYouGet: ['A free kit of care items for you and your baby'],
    whoCanGet:
        'Women who deliver in a government hospital. Some sources say only BPL, SC and ST women. Ask your ASHA.',
    howToGet: [
      'Deliver in a government hospital',
      'The kit is given after delivery. No separate form is needed',
    ],
    source: 'Karnataka scheme listings (secondary websites. Please confirm)',
    lastVerified: _checked,
    status: BenefitStatus.checkWithAsha,
  ),
  BenefitScheme(
    id: 'ration',
    title: 'Ration card food (whole family)',
    summary: 'Free grain from the ration shop. Rules are changing',
    icon: Icons.shopping_basket_outlined,
    color: _teal,
    whatYouGet: [
      'Free grain every month for BPL and Antyodaya ration card holders',
      'The extra rice may be replaced by a food kit. Ask what is given this month',
    ],
    whoCanGet:
        'Families with a BPL, Priority or Antyodaya ration card. This is for the whole family, not only pregnant women.',
    howToGet: [
      'Take your ration card to your ration shop',
      'Ask what is being given this month',
    ],
    documents: ['Ration card', 'Aadhaar linked to the ration card'],
    officialUrl: 'https://ahara.kar.nic.in',
    source: 'Karnataka Food & Civil Supplies (Ahara) and news reports',
    lastVerified: _checked,
    status: BenefitStatus.checkWithAsha,
  ),
];