"""Native presentation of verified text; only essential diagram regions are images.

Unreviewed OCR is not promoted to authoritative text. Each editorial row already
contains the individually checked conditions and all four choices. Original
whole-question crops stay in production evidence, outside converted app assets.
"""
import json,hashlib
from pathlib import Path
import fitz

ROOT=Path(__file__).resolve().parents[2]
DOCS=ROOT/'docs/applied-information';APP=ROOT/'Qualifications/applied-information'
ORIGINALS=DOCS/'evidence/question-crops'
DIAGRAMS={
 'ap-2023-autumn-q22':(.34,.135,.68,.35),
 'ap-2023-autumn-q23':(.05,.32,.95,.70),
 'ap-2025-spring-q06':(.03,.065,.97,.90),
 'ap-2024-spring-q47':(.03,.13,.97,.92),
 'ap-2024-spring-q21':(.03,.125,.97,.61),
 'ap-2025-autumn-q22':(.03,.13,.97,.62),
 'ap-2024-autumn-q21':(.03,.195,.97,.94),
}

def table(headers,rows):return dict(type='table',headers=headers,rows=rows)
CODES={
 'ap-2023-autumn-q29':[dict(type='monospace',text='SELECT DISTINCT 製品番号 FROM 製品\nWHERE NOT EXISTS (\n  SELECT 製品番号 FROM 在庫\n  WHERE 在庫数 > 30\n    AND 製品.製品番号 = 在庫.製品番号\n)')],
}
TABLES={
 'ap-2023-autumn-q29':[table(['製品番号','製品名','単価'],[['AB1805','CD-ROMドライブ','15,000'],['CC5001','デジタルカメラ','65,000'],['MZ1000','プリンタA','54,000'],['XZ3000','プリンタB','78,000'],['ZZ9900','イメージスキャナ','98,000']]),table(['倉庫コード','製品番号','在庫数'],[['WH100','AB1805','20'],['WH100','CC5001','200'],['WH100','ZZ9900','130'],['WH101','AB1805','150'],['WH101','XZ3000','30'],['WH102','XZ3000','20'],['WH102','ZZ9900','10'],['WH103','CC5001','40']])],
 'ap-2023-autumn-q30':[table(['処理','Read','Write','開始','コミット'],[['T1','10','20','チェックポイント前','チェックポイント前'],['T2','10','20','チェックポイント前','チェックポイント後・障害前'],['T3','100','0','チェックポイント後','障害時は未コミット'],['T4','100','0','チェックポイント前','障害時は未コミット'],['T5','20','10','チェックポイント後','障害前'],['T6','20','10','チェックポイント後','障害時は未コミット']])],
 'ap-2023-autumn-q23':[table(['A','B','C','Y'],[['0','0','0','0'],['0','0','1','0'],['0','1','0','0'],['0','1','1','1'],['1','0','0','0'],['1','0','1','1'],['1','1','0','1'],['1','1','1','1']])],
 'ap-2023-autumn-q06':[table(['状態','データ列'],[['0','3, 5, 9, 6, 1, 2'],['1','3, 5, 6, 1, 2, 9'],['2','3, 5, 1, 2, 6, 9'],['…','中間の状態は省略'],['N','1, 2, 3, 5, 6, 9']])],
 'ap-2023-autumn-q04':[table(['行＼列','1','2','3','4','行パリティ'],[['1','1','0','0','0','1'],['2','0','1','1','0','0'],['3','0','0','1','0','1'],['4','1','1','0','1','1'],['列パリティ','0','0','0','1','—（未使用）']])],
 'ap-2023-autumn-q05':[table(['要素番号','elem','next','prev'],[['1','A','4','0'],['2','F','0','5'],['3','D','5','4'],['4','B','3','1'],['5','E','2','3'],['6','追加用（空欄）','空欄','空欄']]),table(['変数','値'],[['Head','1'],['Tail','2']])],
 'ap-2025-spring-q08':[table(['コンピュータ','クロック周期','CPI'],[['A','1ナノ秒','4.0'],['B','4ナノ秒','0.5']])],
 'ap-2025-spring-q16':[table(['プログラムの利用方法','a','b','c','d'],[['OSSのソースコードを修正','○','○','○','×'],['OSSに静的にリンク','○','○','×','×'],['OSSに動的にリンク','○','×','×','×']])],
 'ap-2025-spring-q76':[table(['項目（百万円）','卸売業A社','小売業B社'],[['売上高','800','1,000'],['営業利益','20','90'],['総資産','100','900']])],
 'ap-2025-autumn-q77':[table(['製品','販売単価','変動費/個','製造時間/個'],[['A','30,000円','18,000円','8時間'],['B','25,000円','10,000円','12時間']])],
 'ap-2024-autumn-q75':[table(['A社＼B社（Aのシェア, Bのシェア）','b1','b2'],[['a1','40%, 20%','50%, 30%'],['a2','30%, 10%','25%, 25%']])],
 'ap-2025-autumn-q19':[table(['ブロック','ロード（秒）','最終参照（秒）','参照回数'],[['C0','0','8','10'],['C1','3','6','1'],['C2','4','5','3'],['C3','5','10','5']])],
 'ap-2025-spring-q66':[table(['工程','契約形態'],[['要件定義','a'],['システム外部設計','準委任型又は請負型'],['システム内部設計','b'],['ソフトウェア設計\nプログラミング\nソフトウェアテスト','請負型'],['システム結合','c'],['システムテスト','準委任型又は請負型'],['運用テスト','d']])],
 'ap-2025-autumn-q15':[table(['ジョブ','到着（秒）','処理（秒）'],[['A','0','2'],['B','1','4'],['C','2','3'],['D','3','2'],['E','4','1']])],
 'ap-2025-autumn-q65':[table(['項目','重み','結果（0〜3）'],[['1','5','3'],['2','8','0'],['3','12','1']])],
 'ap-2024-autumn-q77':[table(['項目（億円）','A社','B社'],[['売上','1,000','1,000'],['変動費','500','800'],['固定費','400','100'],['営業利益','100','100']])],
 'ap-2024-autumn-q73':[table(['親品目','a','b','c'],[['A','3','2','0'],['a','—','1','2']]),table(['品目','在庫（個）'],[['A','100'],['a','100'],['b','300'],['c','400']])],
 'ap-2024-autumn-q64':[table(['シナリオ','当該業務の人数','外部委託'],[['a','4人','する'],['b','4人','しない'],['c','5人','する'],['d','5人','しない']])],
 'ap-2024-autumn-q72':[table(['前＼次','a','b','c','d'],[['a','—','2','1','2'],['b','1','—','1','2'],['c','3','2','—','2'],['d','4','3','2','—']])],
 'ap-2025-autumn-q01':[table(['AB＼CD','00','01','11','10'],[['00','1','0','0','1'],['01','0','1','1','0'],['11','0','1','1','0'],['10','0','0','0','0']])],
 'ap-2024-spring-q17':[table(['プロセス','Xの順位','Yの順位','Zの順位'],[['A','1','2','3'],['B','1','2','3'],['C','2','3','1'],['D','3','2','1']])],
 'ap-2024-spring-q26':[table(['部品ID','発注点'],[['P01','100'],['P02','150'],['P03','100']]),table(['部品ID','倉庫ID','在庫数'],[['P01','W01','90'],['P01','W02','90'],['P02','W01','150']])],
 'ap-2024-spring-q54':[table(['案','投資（億円）','需要大の収入','需要小の収入'],[['新規開発','100','180','50'],['既存改修','50','120','40']])],
 'ap-2024-spring-q55':[table(['方式','単価','月の利用'],[['時間','4,000円/時間','250時間'],['件数','700円/件','1,500件'],['容量','300円/GB','3,300GB'],['ID','1,600円/ID','650 ID']])],
 'ap-2024-spring-q64':[table(['案','1年','2年','3年','4年','5年'],[['a','100','150','200','250','300'],['b','100','200','300','200','100'],['c','200','150','100','150','200'],['d','300','200','100','50','50']])],
 'ap-2024-spring-q75':[table(['部品','Xに必要','Yに必要','利用可能'],[['A','3個','2個','120個'],['B','1個','2個','60個']])],
 'ap-2025-autumn-q75':[table(['原料','Xに必要','Yに必要','利用可能'],[['A','3kg','2kg','120kg'],['B','1kg','2kg','60kg']])],
 'ap-2024-spring-q76':[table(['今年度の項目','値'],[['販売台数','2,500台'],['単価','200千円/台'],['固定費','150,000千円'],['変動費','100千円/台']])],
 'ap-2024-spring-q77':[table(['項目','百万円'],[['売上','500'],['材料費（変動）','200'],['外注費（変動）','100'],['製造固定費','100'],['総利益','100'],['販売固定費','80'],['利益','20']])],
}

def extra_conditions(row):
    text=row['accessibilityText']
    if '\n図表：' not in text:return None
    return text.split('\n図表：',1)[1].split('\nア：',1)[0].strip()

def diagram(row,crop):
    origin=row.get('reusedFrom',row['id'])
    if origin not in DIAGRAMS:return None
    assert len(crop['crops'])==1,'Multi-page diagrams need explicit selection'
    record=crop['crops'][0];u0,v0,u1,v1=DIAGRAMS[origin]
    x0,y0,x1,y1=record['box']
    box=[x0+(x1-x0)*u0,y0+(y1-y0)*v0,x0+(x1-x0)*u1,y0+(y1-y0)*v1]
    pdf=fitz.open(DOCS/'evidence'/crop['booklet']);page=pdf[record['page']-1]
    clip=fitz.Rect(box[0]*page.rect.width,box[1]*page.rect.height,box[2]*page.rect.width,box[3]*page.rect.height)
    asset=row['id']+'-diagram.jpg';out=APP/'Figures'/asset
    page.get_pixmap(matrix=fitz.Matrix(2.4,2.4),clip=clip,alpha=False).save(out,jpg_quality=90)
    return dict(type='image',assetName=asset,altText=extra_conditions(row) or row['accessibilityText'],caption='IPA公式原問の図（タップで拡大）'),dict(asset=asset,booklet=crop['booklet'],page=record['page'],box=box,sha256=hashlib.sha256(out.read_bytes()).hexdigest())

def apply_native(questions,editorial,crops):
    by_id={c['id']:c for c in crops};records=[]
    for question in questions:
        row=editorial.get(question['id'])
        if not row:continue
        blocks=[dict(type='text',text=row['stem'])]
        origin=row.get('reusedFrom',row['id'])
        blocks.extend(CODES.get(origin,[]))
        blocks.extend(TABLES.get(origin,[]))
        image=diagram(row,by_id[row['id']])
        if image:
            blocks.append(image[0]);records.append(image[1])
        elif extra:=extra_conditions(row):
            if origin not in TABLES:blocks.append(dict(type='text',text=extra))
        question['bodyBlocks']=blocks
    # Whole-question originals are production evidence, never needed for a
    # verified text presentation. Pending questions still reference their crop.
    used={b['assetName'] for q in questions for b in q.get('bodyBlocks',[]) if b['type']=='image'}
    for file in (APP/'Figures').glob('*.jpg'):
        if file.name not in used:file.unlink()
    (DOCS/'diagram-crops.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
    return records
