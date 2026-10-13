#!/usr/bin/env python3
"""Verify AP coverage, official grading provenance, assets and original mocks."""
import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path

from assemble_bank import APP, DOCS, EVIDENCE, dump, load_answers, markers
from predictions import build_sets
from editorial import load_editorial
from presentation import ORIGINALS, TABLES, DIAGRAMS, CODES


def validate(release=False):
    bank=json.loads((APP/"questions.json").read_text())
    config=json.loads((APP/"qualification.json").read_text())
    sources=json.loads((DOCS/"sources.json").read_text())
    qs=bank["questions"]; by_id={q["id"]:q for q in qs}
    assert len(qs)==len(by_id)==2880
    assert len(bank["mockSets"])==36
    assert config["mockQuestionCount"]==80 and config["examMinutes"]==150
    assert len(set(config["freeQuestionIDs"]))==160
    assert all(by_id[i]["year"]==2025 for i in config["freeQuestionIDs"])
    images=set()
    for q in qs:
        assert q["subject"] in config["subjects"]
        assert len(q["choices"])==len(set(q["choices"]))==4
        assert 0<=q["correctIndex"]<4
        assert q["stem"] and q["source"] and q["explanation"]
        if choice_blocks:=q.get("choiceBlocks"):
            assert len(choice_blocks)==4 and all(choice_blocks)
        blocks=q.get("bodyBlocks",[])+[b for choice in q.get("choiceBlocks",[]) for b in choice]+q.get("explanationBlocks",[])
        for block in blocks:
            if block["type"] in ["text","monospace","formula"]:
                assert block["text"].strip(); continue
            if block["type"]=="table":
                assert block["headers"] and block["rows"]
                assert all(len(r)==len(block["headers"]) for r in block["rows"]); continue
            assert block["type"]=="image" and block["altText"]
            name=block["assetName"]
            assert Path(name).name==name and (APP/"Figures"/name).exists()
            images.add(name)
    for s in bank["mockSets"]:
        questions=[by_id[i] for i in s["questionIDs"]]
        assert len(questions)==s["questionCount"]==80 and s["minutes"]==150
        assert [q["questionNumber"] for q in questions]==list(range(1,81))
        assert all(q["mockSetID"]==s["id"] for q in questions)
    verified=0
    for row in sources["years"]:
        for doc in row["documents"]:
            assert hashlib.sha256((EVIDENCE/doc["file"]).read_bytes()).hexdigest()==doc["sha256"]
            if doc["section"]!="A" or doc["role"]!="ans": continue
            booklet=next(d for d in row["documents"] if d["section"]=="A" and d["role"]=="qs" and d["administration"]==doc["administration"])
            ocr=json.loads((EVIDENCE/Path(booklet["file"]).with_suffix(".ocr.json")).read_text())
            _,ranges=markers(ocr)
            for n,(correct,subject) in load_answers(doc,ranges).items():
                q=by_id[f"ap-{row['year']}-{doc['administration']}-q{n:02d}"]
                assert q["correctIndex"]==correct and q["subject"]==subject
                verified+=1
    assert verified==2640
    generated,_=build_sets()
    actual=[q for q in qs if q["kind"]=="prediction"]
    assert actual==generated
    assert len({q["stem"] for q in actual})==240
    crops=json.loads((DOCS/"figure-crops.json").read_text())
    assert len(crops)==2640
    for q in crops:
        for crop in q["crops"]:
            assert hashlib.sha256((ORIGINALS/crop["asset"]).read_bytes()).hexdigest()==crop["sha256"]
            a,b,c,d=crop["box"]
            assert 0<=a<c<=1 and 0<=b<d<=1
    assert images=={p.name for p in (APP/"Figures").glob("*.jpg")}
    diagrams=json.loads((DOCS/"diagram-crops.json").read_text())
    for figure in diagrams:
        assert figure["asset"] in images
        assert hashlib.sha256((APP/"Figures"/figure["asset"]).read_bytes()).hexdigest()==figure["sha256"]
        a,b,c,d=figure["box"]
        assert 0<=a<c<=1 and 0<=b<d<=1
    editorial=load_editorial(qs)
    for id_,row in editorial.items():
        question=by_id[id_]
        for field in ["stem","choices","explanation","choiceExplanations","steps","category","difficulty","tags","concepts"]:
            assert question[field]==row[field], f"解説がアプリへ反映されていません: {id_}/{field}"
        if "choiceBlocks" in row:
            assert question["choiceBlocks"]==row["choiceBlocks"]
        assert question["bodyBlocks"][0]==dict(type="text",text=row["stem"])
        origin=row.get("reusedFrom",row["id"])
        assert [b for b in question["bodyBlocks"] if b["type"]=="table"]==TABLES.get(origin,[])
        assert [b for b in question["bodyBlocks"] if b["type"]=="monospace"]==CODES.get(origin,[])
        assert any(b["type"]=="image" for b in question["bodyBlocks"])==(origin in DIAGRAMS)
    pending=sorted(q["id"] for q in qs if q["kind"]=="past" and q["id"] not in editorial)
    dump(DOCS/"editorial-progress.json",dict(total=verified,reviewed=len(editorial),pending=len(pending),
         reviewType="制作内AI校閲（外部専門家による校閲ではない）",
         sets={s["id"]:dict(reviewed=sum(i in editorial for i in s["questionIDs"]),total=80)
               for s in bank["mockSets"] if s["kind"]=="past"},pendingIDs=pending))
    assert not (APP/"written-booklets.json").exists()
    assert not (APP/"WrittenResources").exists()
    if release:
        assert not pending, f"過去問の詳細解説・原問校合・読み上げ校閲が未完了: {len(pending)}問"
        assert bank.get("isDraft") is False, "公開前に全原問の目視校合・読み上げ・教材の校閲を完了してください。"
        assert config["privacyPolicyURL"], "公開用プライバシーポリシーが必要です。"
    return dict(status="passed",releaseReady=False,officialDocuments=sum(len(r["documents"]) for r in sources["years"]),
                pastQuestions=verified,predictionQuestions=len(actual),mockSets=36,freeQuestions=160,
                figures=len(images),nativeTextQuestions=len(editorial)+len(actual),nativePastTextQuestions=len(editorial),
                nativeTableQuestions=sum(any(b["type"]=="table" for b in q.get("bodyBlocks",[])) for q in qs),writtenBooklets=0,offlineWrittenBooklets=0,
                detailedPastExplanations=len(editorial),pastEditorialPending=len(pending),
                limitations=[f"過去問の詳細解説・原問校合・読み上げ校閲は{len(editorial)}/{verified}問完了（制作内AI校閲）",
                             "予想問題の外部専門家による校閲は未実施", "本番IAP・広告・公開ポリシー・審査提出は未実施"])


if __name__=="__main__":
    parser=argparse.ArgumentParser();parser.add_argument("--release",action="store_true")
    args=parser.parse_args()
    report=validate(args.release)
    dump(DOCS/"validation-report.json",report)
    print(json.dumps(report,ensure_ascii=False,indent=2))
