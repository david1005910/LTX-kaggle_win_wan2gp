# overlays/ — Wan2GP 클론 위에 얹는 보조 파일들

업스트림 `Wan2GP/` 클론 자체는 이 리포 밖(`E:\LTX-Kaggle\Wan2GP\`)에 있고 origin이 DeepBeepMeep/Wan2GP라 push 권한이 없습니다. 그 클론 안에 추가/수정한 작은 파일들만 여기 따로 보존해서 같이 관리합니다.

```
overlays/
├── CLAUDE.md                       → Wan2GP/CLAUDE.md
├── scripts/
│   └── args.txt                    → Wan2GP/scripts/args.txt
└── settings/
    ├── test_smoke.json             → Wan2GP/settings/test_smoke.json
    └── test_smoke2.json            → Wan2GP/settings/test_smoke2.json
```

## 각 파일의 역할

| 파일 | 설명 |
| --- | --- |
| `CLAUDE.md` | Claude Code(`claude.ai/code`)가 이 리포에서 작업할 때 쓰는 프로젝트 가이드. 큰 그림 아키텍처, 자주 쓰는 명령, 편집 규약 정리 |
| `scripts/args.txt` | 업스트림 `scripts/run.bat`이 `python wgp.py` 뒤에 붙여줄 추가 인자. 현재는 `--t2v-1-3B --profile 4 --attention sdpa --perc-reserved-mem-max 0.4 --listen --server-port 7860`. 이 리포의 `run_wan2gp.sh/bat`가 동일 인자를 직접 들고 있으니 참고용 |
| `settings/test_smoke.json` | `test_wan2gp.sh/bat`가 사용하는 최소 스모크 테스트 settings (스포츠카, seed=42, 832×480, 25프레임, 15스텝) |
| `settings/test_smoke2.json` | 두 번째 테스트 settings (코이 연못 + 벚꽃, seed=7777) |

## 적용 방법

새 머신에 Wan2GP 클론을 막 받은 상태라면 다음 한 줄로 모두 복사:

```bash
cp -r overlays/* /mnt/e/LTX-Kaggle/Wan2GP/
```

또는 윈도우에서:

```cmd
xcopy /E /Y E:\LTX-Kaggle\overlays\* E:\LTX-Kaggle\Wan2GP\
```

이후 흐름:
- `bash setup_wan2gp.sh` 로 의존성 설치 (1회)
- `bash run_wan2gp.sh` 또는 더블클릭 `run_wan2gp.bat` 로 웹 UI 기동
- `bash test_wan2gp.sh` 또는 `test_wan2gp.bat` 로 스모크 테스트 1건

## 동기화 시 주의

오버레이 파일을 수정한 위치(Wan2GP/ 안)에서 작업했다면, 이 리포에 반영하려면 수동 복사가 필요합니다:

```bash
cp /mnt/e/LTX-Kaggle/Wan2GP/CLAUDE.md            overlays/CLAUDE.md
cp /mnt/e/LTX-Kaggle/Wan2GP/scripts/args.txt     overlays/scripts/args.txt
cp /mnt/e/LTX-Kaggle/Wan2GP/settings/test_smoke.json   overlays/settings/test_smoke.json
cp /mnt/e/LTX-Kaggle/Wan2GP/settings/test_smoke2.json  overlays/settings/test_smoke2.json
git add overlays && git commit -m "overlays: sync from Wan2GP/"
```

## requirements.txt 패치는 왜 없나

업스트림 `requirements.txt`에서 `vector-quantize-pytorch` 한 줄을 제거해야 합니다(이 환경에서 설치 충돌). `setup_wan2gp.sh`가 `sed`로 자동 처리하므로 별도 보존하지 않습니다.
