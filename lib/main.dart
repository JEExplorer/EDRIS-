
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = BusinessStore();
  await store.load();
  runApp(BusinessApp(store: store));
}

const navy = Color(0xFF101D32);
const ink = Color(0xFF172A45);
const gold = Color(0xFFE8B45B);
const green = Color(0xFF159B75);
const red = Color(0xFFD95C62);
const page = Color(0xFFF3F5F9);

const labels = <String,String>{
 'products':'محصولات و انبار','sales':'فروش','purchases':'خرید',
 'expenses':'مصارف','debts':'بدهکاری‌ها','customers':'مشتریان',
 'suppliers':'تأمین‌کنندگان','employees':'کارمندان'
};
const icons = <String,IconData>{
 'products':Icons.inventory_2_rounded,'sales':Icons.point_of_sale_rounded,
 'purchases':Icons.shopping_bag_rounded,'expenses':Icons.receipt_long_rounded,
 'debts':Icons.account_balance_wallet_rounded,'customers':Icons.people_alt_rounded,
 'suppliers':Icons.local_shipping_rounded,'employees':Icons.badge_rounded
};

class BusinessStore extends ChangeNotifier {
  static const key = 'abp_data_v3';
  final Map<String,List<Map<String,dynamic>>> data = {
    for (final k in labels.keys) k:<Map<String,dynamic>>[]
  };
  String shopName = 'افغان بیزنس پرو';
  String currency = 'افغانی';
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key);
    if (raw == null) {
      data['products']!.addAll([
        {'id':'sample1','name':'محصول نمونه','category':'عمومی','qty':15,'min':3,'cost':120,'price':180,'barcode':'','note':'نمونه آزمایشی'}
      ]);
      await save();
      return;
    }
    try {
      final m = jsonDecode(raw) as Map<String,dynamic>;
      for (final k in labels.keys) {
        data[k] = ((m[k] as List?) ?? []).map((e)=>Map<String,dynamic>.from(e)).toList();
      }
      shopName = m['shopName'] ?? shopName;
      currency = m['currency'] ?? currency;
    } catch (_) { /* keep a usable empty store if an old backup is damaged */ }
  }
  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key,jsonEncode({...data,'shopName':shopName,'currency':currency}));
    notifyListeners();
  }
  List<Map<String,dynamic>> get products=>data['products']!;
  List<Map<String,dynamic>> get sales=>data['sales']!;
  List<Map<String,dynamic>> get purchases=>data['purchases']!;
  List<Map<String,dynamic>> get expenses=>data['expenses']!;
  List<Map<String,dynamic>> get debts=>data['debts']!;
  double sum(String type,String field)=>data[type]!.fold(0.0,(s,r)=>s+(r[field] as num? ?? 0).toDouble());
  double get salesTotal=>sum('sales','total');
  double get purchaseTotal=>sum('purchases','total');
  double get expenseTotal=>sum('expenses','amount');
  double get debtTotal=>sum('debts','balance');
  double get grossProfit=>sales.fold(0.0,(s,r)=>s+((r['profit'] as num? ?? 0).toDouble()));
  double get netProfit=>grossProfit-expenseTotal;
  int get stockCount=>products.fold(0,(s,r)=>s+(r['qty'] as int? ?? 0));
  List<Map<String,dynamic>> get lowStock=>products.where((p)=>(p['qty'] as int? ?? 0)<=(p['min'] as int? ?? 0)).toList();
  String money(num n)=>'${n.toStringAsFixed(0)} $currency';
  Future<void> upsert(String type,Map<String,dynamic> row) async {
    final list=data[type]!;
    final i=list.indexWhere((e)=>e['id']==row['id']);
    if(i<0) list.add(row); else list[i]=row;
    await save();
  }
  Future<void> remove(String type,String id) async {
    data[type]!.removeWhere((e)=>e['id']==id);
    await save();
  }
  Future<void> exportBackup() async {
    final dir=await getTemporaryDirectory();
    final f=File('${dir.path}/Afghan_Business_Pro_Backup.json');
    await f.writeAsString(jsonEncode({...data,'shopName':shopName,'currency':currency}));
    await Share.shareXFiles([XFile(f.path)],text:'نسخه پشتیبان افغان بیزنس پرو');
  }
  Future<void> importBackup() async {
    final result=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['json'],withData:true);
    if(result==null) return;
    final bytes=result.files.single.bytes;
    if(bytes==null) throw Exception('خواندن فایل ممکن نشد');
    final m=jsonDecode(utf8.decode(bytes)) as Map<String,dynamic>;
    for(final k in labels.keys) {
      data[k]=((m[k] as List?)??[]).map((e)=>Map<String,dynamic>.from(e)).toList();
    }
    shopName=m['shopName']??shopName; currency=m['currency']??currency;
    await save();
  }
  Future<void> exportCsv(String type) async {
    final rows=data[type]!;
    final keys=<String>{'name','date','category','qty','price','cost','total','amount','balance','phone','note'};
    final b=StringBuffer('\uFEFF');
    b.writeln(keys.join(','));
    for(final r in rows) {
      b.writeln(keys.map((k)=>'"${(r[k]??'').toString().replaceAll('"','""')}"').join(','));
    }
    final dir=await getTemporaryDirectory();
    final f=File('${dir.path}/${type}_export.csv');
    await f.writeAsString(b.toString());
    await Share.shareXFiles([XFile(f.path)],text:'خروجی ${labels[type]}');
  }
}

class BusinessApp extends StatelessWidget {
 final BusinessStore store;
 const BusinessApp({super.key,required this.store});
 @override Widget build(BuildContext context)=>AnimatedBuilder(
  animation:store,builder:(_,__)=>MaterialApp(
   debugShowCheckedModeBanner:false,title:'افغان بیزنس پرو',
   theme:ThemeData(useMaterial3:true,scaffoldBackgroundColor:page,
    colorScheme:ColorScheme.fromSeed(seedColor:ink,primary:ink,secondary:gold),
    fontFamily:'Arial',inputDecorationTheme:InputDecorationTheme(
     filled:true,fillColor:Colors.white,contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:13),
     border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide.none))),
   home:Directionality(textDirection:TextDirection.rtl,child:Home(store:store)),
  ));
}

class Home extends StatefulWidget {
 final BusinessStore store;
 const Home({super.key,required this.store});
 @override State<Home> createState()=>_HomeState();
}
class _HomeState extends State<Home> {
 int selected=0;
 final pages=['داشبورد',...labels.values,'گزارش‌ها','تنظیمات'];
 @override Widget build(BuildContext context) {
  final keys=labels.keys.toList();
  Widget body;
  if(selected==0) body=Dashboard(store:widget.store,onOpen:(i)=>setState(()=>selected=i));
  else if(selected<=keys.length) body=RecordsPage(store:widget.store,type:keys[selected-1]);
  else if(selected==keys.length+1) body=ReportsPage(store:widget.store);
  else body=SettingsPage(store:widget.store);
  return Scaffold(
   appBar:AppBar(backgroundColor:navy,foregroundColor:Colors.white,title:Row(children:[
    Container(width:36,height:36,decoration:BoxDecoration(color:gold,borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.storefront_rounded,color:navy)),
    const SizedBox(width:10),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Text(widget.store.shopName,style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold)),
     Text(pages[selected],style:const TextStyle(fontSize:11,color:Colors.white70))
    ])]),
    actions:[IconButton(onPressed:()=>setState(()=>selected=keys.length+2),icon:const Icon(Icons.settings_outlined))]),
   drawer:Drawer(child:Container(color:navy,child:Column(children:[
    const SizedBox(height:42),const Icon(Icons.store_mall_directory_rounded,color:gold,size:44),
    const SizedBox(height:8),const Text('AFGHAN BUSINESS PRO',style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold,letterSpacing:1)),
    const Divider(color:Colors.white24,height:32),
    Expanded(child:ListView.builder(itemCount:pages.length,itemBuilder:(c,i)=>ListTile(
     selected:selected==i,selectedTileColor:Colors.white12,
     leading:Icon(i==0?Icons.dashboard_rounded:i==pages.length-2?Icons.analytics_rounded:i==pages.length-1?Icons.settings:icons[keys[i-1]],color:selected==i?gold:Colors.white70),
     title:Text(pages[i],style:TextStyle(color:Colors.white,fontWeight:selected==i?FontWeight.bold:FontWeight.normal)),
     onTap:(){setState(()=>selected=i);Navigator.pop(context);}))),
    const Padding(padding:EdgeInsets.all(14),child:Text('آفلاین • ذخیره روی همین دستگاه',style:TextStyle(color:Colors.white54,fontSize:11)))
   ]))),
   body:body,
   floatingActionButton:selected>0&&selected<=keys.length?FloatingActionButton.extended(
    backgroundColor:gold,foregroundColor:navy,icon:const Icon(Icons.add),
    label:const Text('ثبت جدید'),onPressed:()=>showEntry(context,widget.store,keys[selected-1])):null,
  );
 }
}

class Dashboard extends StatelessWidget {
 final BusinessStore store; final ValueChanged<int> onOpen;
 const Dashboard({super.key,required this.store,required this.onOpen});
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[
  Container(padding:const EdgeInsets.all(21),decoration:BoxDecoration(
   gradient:const LinearGradient(colors:[navy,Color(0xFF304D70)],begin:Alignment.topRight,end:Alignment.bottomLeft),
   borderRadius:BorderRadius.circular(25)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('مدیریت هوشمند کسب‌وکار',style:TextStyle(color:Colors.white70)),
    const SizedBox(height:8),Text(store.shopName,style:const TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.bold)),
    const SizedBox(height:14),const Row(children:[Icon(Icons.cloud_off,color:gold,size:17),SizedBox(width:6),Text('بدون نیاز به اینترنت',style:TextStyle(color:Colors.white70,fontSize:12))])
  ])),
  const SizedBox(height:16),
  GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,mainAxisSpacing:10,crossAxisSpacing:10,childAspectRatio:1.55,children:[
   Metric(title:'فروش کل',value:store.money(store.salesTotal),icon:Icons.trending_up,color:green),
   Metric(title:'سود خالص تخمینی',value:store.money(store.netProfit),icon:Icons.insights,color:const Color(0xFF6277D8)),
   Metric(title:'موجودی انبار',value:'${store.stockCount} عدد',icon:Icons.inventory_2,color:const Color(0xFFE39A38)),
   Metric(title:'بدهی باقی‌مانده',value:store.money(store.debtTotal),icon:Icons.account_balance_wallet,color:red),
  ]),
  const SizedBox(height:18),const Text('دسترسی سریع',style:TextStyle(fontWeight:FontWeight.bold,fontSize:17,color:ink)),
  const SizedBox(height:10),Wrap(spacing:8,runSpacing:8,children:[
   quick('ثبت فروش',Icons.point_of_sale,2,onOpen),quick('محصول جدید',Icons.add_box,1,onOpen),
   quick('ثبت خرید',Icons.shopping_bag,3,onOpen),quick('گزارش‌ها',Icons.bar_chart,labels.length+1,onOpen)
  ]),
  const SizedBox(height:18),
  if(store.lowStock.isNotEmpty) Card(color:const Color(0xFFFFF2E7),child:ListTile(
   leading:const Icon(Icons.warning_amber_rounded,color:red),title:Text('${store.lowStock.length} محصول به حداقل موجودی رسیده'),
   subtitle:Text(store.lowStock.take(3).map((e)=>e['name']).join('، ')))),
  const SizedBox(height:12),const Text('آخرین فروش‌ها',style:TextStyle(fontWeight:FontWeight.bold,fontSize:17,color:ink)),
  if(store.sales.isEmpty) const Empty(text:'هنوز فروشی ثبت نشده است.')
  else ...store.sales.reversed.take(5).map((r)=>ListTile(
   leading:const CircleAvatar(backgroundColor:Color(0xFFEAF6F1),child:Icon(Icons.receipt_long,color:green)),
   title:Text(r['name']??'فروش'),subtitle:Text(r['date']??''),trailing:Text(store.money(r['total']??0),style:const TextStyle(fontWeight:FontWeight.bold))))
 ]);
 Widget quick(String s,IconData i,int n,ValueChanged<int> f)=>ActionChip(avatar:Icon(i,color:ink),label:Text(s),onPressed:()=>f(n),backgroundColor:Colors.white,padding:const EdgeInsets.all(9));
}

class Metric extends StatelessWidget {
 final String title,value;final IconData icon;final Color color;
 const Metric({super.key,required this.title,required this.value,required this.icon,required this.color});
 @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(
  color:Colors.white,borderRadius:BorderRadius.circular(19),boxShadow:[BoxShadow(color:ink.withOpacity(.04),blurRadius:16,offset:const Offset(0,5))]),
  child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
   Row(children:[Container(padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:color.withOpacity(.12),borderRadius:BorderRadius.circular(11)),child:Icon(icon,color:color)),const Spacer(),const Icon(Icons.more_horiz,color:Colors.black26)]),
   Text(value,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:15,color:ink)),
   Text(title,style:const TextStyle(color:Colors.black54,fontSize:11))
  ]));
}

class RecordsPage extends StatefulWidget {
 final BusinessStore store;final String type;
 const RecordsPage({super.key,required this.store,required this.type});
 @override State<RecordsPage> createState()=>_RecordsPageState();
}
class _RecordsPageState extends State<RecordsPage> {
 String query='';
 List<Map<String,dynamic>> get rows=>widget.store.data[widget.type]!;
 @override Widget build(BuildContext context) {
  final filtered=rows.where((r)=>r.values.any((v)=>v.toString().toLowerCase().contains(query.toLowerCase()))).toList().reversed.toList();
  return Column(children:[
   Padding(padding:const EdgeInsets.fromLTRB(16,14,16,8),child:Row(children:[
    Expanded(child:Text(labels[widget.type]!,style:const TextStyle(fontSize:21,fontWeight:FontWeight.bold,color:ink))),
    Text('${filtered.length} مورد',style:const TextStyle(color:Colors.black54))
   ])),
   Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:TextField(
    onChanged:(v)=>setState(()=>query=v),decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:'جستجو در ${labels[widget.type]}'))),
   Expanded(child:filtered.isEmpty?const Empty(text:'موردی پیدا نشد. برای شروع ثبت جدید را بزنید.'):ListView.builder(
    padding:const EdgeInsets.all(12),itemCount:filtered.length,itemBuilder:(c,i){
     final r=filtered[i];final amount=r['total']??r['amount']??r['balance']??r['price']??0;
     return Card(color:Colors.white,elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),child:ListTile(
      onTap:()=>showEntry(context,widget.store,widget.type,existing:r),
      leading:CircleAvatar(backgroundColor:gold.withOpacity(.2),child:Icon(icons[widget.type],color:ink)),
      title:Text(r['name']??r['person']??'بدون نام',style:const TextStyle(fontWeight:FontWeight.bold)),
      subtitle:Text('${r['date']??r['category']??''}  ${r['note']??''}',maxLines:2,overflow:TextOverflow.ellipsis),
      trailing:PopupMenuButton<String>(onSelected:(v)async{
       if(v=='edit') await showEntry(context,widget.store,widget.type,existing:r);
       if(v=='delete') await widget.store.remove(widget.type,r['id']);
      },itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('ویرایش')),PopupMenuItem(value:'delete',child:Text('حذف'))],
       child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[
        Text(widget.store.money(amount),style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12,color:ink)),
        if(widget.type=='products')Text('موجودی: ${r['qty']??0}',style:const TextStyle(fontSize:10,color:Colors.black54))
       ]))
     ));
    }))
  ]);
 }
}

Future<void> showEntry(BuildContext context,BusinessStore store,String type,{Map<String,dynamic>? existing}) async {
 await showDialog(context:context,builder:(_)=>EntryDialog(store:store,type:type,existing:existing));
}

class EntryDialog extends StatefulWidget {
 final BusinessStore store;final String type;final Map<String,dynamic>? existing;
 const EntryDialog({super.key,required this.store,required this.type,this.existing});
 @override State<EntryDialog> createState()=>_EntryDialogState();
}
class _EntryDialogState extends State<EntryDialog> {
 late final TextEditingController name,amount,qty,cost,category,phone,note,paid,min,barcode;
 String get type=>widget.type;
 bool get isEdit=>widget.existing!=null;
 @override void initState(){
  super.initState();final r=widget.existing??{};
  name=TextEditingController(text:r['name']??r['person']??'');
  amount=TextEditingController(text:(r['price']??r['total']??r['amount']??'').toString());
  qty=TextEditingController(text:(r['qty']??1).toString());
  cost=TextEditingController(text:(r['cost']??'').toString());
  category=TextEditingController(text:r['category']??'عمومی');
  phone=TextEditingController(text:r['phone']??'');
  note=TextEditingController(text:r['note']??'');
  paid=TextEditingController(text:(r['paid']??'').toString());
  min=TextEditingController(text:(r['min']??2).toString());
  barcode=TextEditingController(text:r['barcode']??'');
 }
 @override void dispose(){for(final c in [name,amount,qty,cost,category,phone,note,paid,min,barcode]){c.dispose();}super.dispose();}
 Widget field(TextEditingController c,String label,{bool number=false})=>Padding(padding:const EdgeInsets.only(bottom:9),child:TextField(controller:c,keyboardType:number?const TextInputType.numberWithOptions(decimal:true):TextInputType.text,decoration:InputDecoration(labelText:label)));
 @override Widget build(BuildContext context){
  final product=type=='products',contact=['customers','suppliers','employees'].contains(type);
  final title=isEdit?'ویرایش':'ثبت';
  return Directionality(textDirection:TextDirection.rtl,child:AlertDialog(
   title:Text('$title ${labels[type]}'),content:SizedBox(width:380,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    field(name,contact?'نام کامل':'نام'),
    if(product) ...[field(category,'دسته‌بندی'),field(amount,'قیمت فروش',number:true),field(cost,'قیمت خرید / تمام‌شده',number:true),field(qty,'موجودی',number:true),field(min,'حداقل موجودی',number:true),field(barcode,'بارکد (اختیاری)')],
    if(['sales','purchases'].contains(type)) ...[field(qty,'تعداد',number:true),field(amount,'قیمت هر واحد',number:true),field(paid,'مبلغ پرداخت‌شده',number:true)],
    if(['expenses','debts'].contains(type)) ...[field(amount,'مبلغ',number:true),if(type=='debts')field(paid,'مبلغ پرداخت‌شده',number:true)],
    if(contact)field(phone,'شماره تماس'),
    field(note,'یادداشت')
   ]))),actions:[
    TextButton(onPressed:()=>Navigator.pop(context),child:const Text('لغو')),
    FilledButton(onPressed:_save,child:const Text('ذخیره'))
   ]));
 }
 Future<void> _save() async {
  if(name.text.trim().isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('نام را وارد کنید.')));return;}
  double n(TextEditingController c)=>double.tryParse(c.text.trim())??0;
  final id=widget.existing?['id']??DateTime.now().microsecondsSinceEpoch.toString();
  final row=<String,dynamic>{'id':id,'name':name.text.trim(),'date':widget.existing?['date']??DateTime.now().toIso8601String().substring(0,10):DateTime.now().toIso8601String().substring(0,10),'note':note.text.trim(),'phone':phone.text.trim()};
  if(type=='products'){
   row.addAll({'category':category.text.trim(),'price':n(amount),'cost':n(cost),'qty':q,'min':int.tryParse(min.text)??2,'barcode':barcode.text.trim()});
  } else if(type=='sales'||type=='purchases'){
   final count=q;final unit=n(amount);final total=count*unit;final payment=n(paid);
   row.addAll({'qty':count,'unitPrice':unit,'total':total,'paid':payment,'balance':(total-payment).clamp(0,total)});
   if(type=='sales'){
    final p=widget.store.products.where((e)=>e['name']==name.text.trim()).toList();
    if(p.isNotEmpty&&!isEdit&&(p.first['qty'] as int)<count){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('موجودی کافی نیست.')));return;}
    if(p.isNotEmpty&&!isEdit){p.first['qty']=(p.first['qty'] as int)-count;}
    row['profit']=p.isEmpty?0:(unit-(p.first['cost'] as num? ?? 0))*count;
   } else if(!isEdit){
    final p=widget.store.products.where((e)=>e['name']==name.text.trim()).toList();
    if(p.isNotEmpty)p.first['qty']=(p.first['qty'] as int)+count;
   }
  } else if(type=='expenses')row['amount']=n(amount);
  else if(type=='debts'){row['amount']=n(amount);row['paid']=n(paid);row['balance']=(n(amount)-n(paid)).clamp(0,n(amount));}
  else row['category']=category.text.trim();
  await widget.store.upsert(type,row);
  if(mounted)Navigator.pop(context);
 }
}

class ReportsPage extends StatelessWidget {
 final BusinessStore store;
 const ReportsPage({super.key,required this.store});
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[
  const Text('گزارش‌های کسب‌وکار',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold,color:ink)),
  const SizedBox(height:12),
  report('فروش کل',store.money(store.salesTotal),Icons.trending_up,green),
  report('خرید کل',store.money(store.purchaseTotal),Icons.shopping_bag,Colors.orange),
  report('سود ناخالص ثبت‌شده',store.money(store.grossProfit),Icons.insights,Colors.indigo),
  report('مصارف',store.money(store.expenseTotal),Icons.receipt_long,red),
  report('سود خالص تخمینی',store.money(store.netProfit),Icons.account_balance,green),
  report('بدهی باقی‌مانده مشتریان/حساب‌ها',store.money(store.debtTotal),Icons.account_balance_wallet,red),
  report('تعداد محصولات کم‌موجود', '${store.lowStock.length}',Icons.warning_amber,Colors.deepOrange),
  const SizedBox(height:14),const Text('خروجی اطلاعات',style:TextStyle(fontWeight:FontWeight.bold,fontSize:17)),
  ...labels.entries.map((e)=>Card(color:Colors.white,child:ListTile(leading:Icon(Icons.download,color:ink),title:Text('خروجی ${e.value} به CSV'),onTap:()=>store.exportCsv(e.key))))
 ]);
 Widget report(String title,String value,IconData icon,Color c)=>Card(color:Colors.white,elevation:0,child:ListTile(leading:CircleAvatar(backgroundColor:c.withOpacity(.12),child:Icon(icon,color:c)),title:Text(title),trailing:Text(value,style:const TextStyle(fontWeight:FontWeight.bold,color:ink))));
}

class SettingsPage extends StatelessWidget {
 final BusinessStore store;
 const SettingsPage({super.key,required this.store});
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[
  const Text('تنظیمات و پشتیبان‌گیری',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold,color:ink)),
  Card(color:Colors.white,child:ListTile(leading:const Icon(Icons.store,color:ink),title:const Text('نام فروشگاه'),subtitle:Text(store.shopName),trailing:const Icon(Icons.edit),onTap:()async{
   final c=TextEditingController(text:store.shopName);
   final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('نام فروشگاه'),content:TextField(controller:c),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('ذخیره'))]));
   if(ok==true){store.shopName=c.text.trim().isEmpty?'افغان بیزنس پرو':c.text.trim();await store.save();}
  })),
  Card(color:Colors.white,child:ListTile(leading:const Icon(Icons.currency_exchange,color:ink),title:const Text('واحد پول'),subtitle:Text(store.currency),trailing:const Icon(Icons.edit),onTap:()async{
   final c=TextEditingController(text:store.currency);
   final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('واحد پول'),content:TextField(controller:c),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('ذخیره'))]));
   if(ok==true){store.currency=c.text.trim().isEmpty?'افغانی':c.text.trim();await store.save();}
  })),
  Card(color:Colors.white,child:ListTile(leading:const Icon(Icons.backup,color:green),title:const Text('ساخت نسخه پشتیبان'),subtitle:const Text('ذخیره تمام اطلاعات در فایل JSON'),onTap:()=>store.exportBackup())),
  Card(color:Colors.white,child:ListTile(leading:const Icon(Icons.restore,color:ink),title:const Text('بازیابی نسخه پشتیبان'),subtitle:const Text('جایگزینی اطلاعات فعلی با فایل پشتیبان'),onTap:()async{
   final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('تأیید بازیابی'),content:const Text('اطلاعات فعلی با نسخه پشتیبان جایگزین می‌شود. ادامه می‌دهید؟'),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('ادامه'))]));
   if(ok==true){try{await store.importBackup();}catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('خطا: $e')));}}
  })),
  const Card(color:Colors.white,child:ListTile(leading:Icon(Icons.offline_bolt,color:gold),title:Text('حالت آفلاین'),subtitle:Text('اطلاعات به‌صورت محلی روی همین دستگاه نگهداری می‌شود.'))),
  const Padding(padding:EdgeInsets.all(12),child:Text('توجه: برای امنیت، نسخه پشتیبان را در جای امن نگهداری کنید. سود و گزارش‌ها بر اساس اطلاعات ثبت‌شده محاسبه می‌شوند.',style:TextStyle(color:Colors.black54)))
 ]);
}

class Empty extends StatelessWidget {
 final String text;
 const Empty({super.key,required this.text});
 @override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[
  const Icon(Icons.inbox_rounded,size:48,color:Colors.black26),const SizedBox(height:10),Text(text,textAlign:TextAlign.center,style:const TextStyle(color:Colors.black54))
 ])));
}
