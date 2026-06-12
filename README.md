# WanGP 로컬 실행 가이드 (WSL + Windows)

이 폴더(`E:\LTX-Kaggle\`)에는 WanGP 리포지토리(`Wan2GP/`)와 그것을 WSL/Windows에서 띄우기 위한 래퍼 스크립트들이 있습니다.

| 파일 | 역할 |
| --- | --- |
| `Wan2GP/` | 업스트림 WanGP 소스 (https://github.com/deepbeepmeep/Wan2GP) |
| `setup_wan2gp.sh` | conda env(`wan2gp`) + 의존성 1회 설치 |
| `run_wan2gp.sh` | WSL/리눅스용 실행기 (conda activate → `python wgp.py …`) |
| `run_wan2gp.bat` | 윈도우용 실행기 (cmd/탐색기 더블클릭 → 내부적으로 `wsl.exe`로 위 .sh 호출) |
| `Wan2GP/scripts/args.txt` | `python wgp.py`에 붙일 추가 인자(공식 `scripts/run.bat`이 읽음, 현재는 참고용) |
| `test_wan2gp.sh` / `test_wan2gp.bat` | 스모크 테스트 — 짧은 t2v_1.3B 클립을 헤드리스로 1건 생성 후 결과 폴더 열기 |
| `Wan2GP/settings/test_smoke.json` | 위 스모크 테스트가 사용하는 최소 settings (832×480, 25프레임, 15스텝, seed=42) |
| `overlays/` | `Wan2GP/` 클론 안에 얹어 쓰는 보조 파일들의 백업 (`CLAUDE.md`, `scripts/args.txt`, `settings/test_smoke*.json`). 새 머신에서는 `cp -r overlays/* Wan2GP/`로 한 번에 복원. 자세히는 `overlays/README.md` |

---

## 1. 최초 설치 (한 번만)

WSL 셸에서:

```bash
bash /mnt/e/LTX-Kaggle/setup_wan2gp.sh
```

수행 내용:
- `Wan2GP/` 클론(없을 때)
- conda env `wan2gp` 생성 (Python 3.10.9)
- PyTorch 2.7.1 + CUDA 12.8 휠 설치
- `requirements.txt` 설치 (사전 충돌 패키지 한 줄 제거 후)

설치 후 conda 위치: `/home/sharkey/anaconda3/envs/wan2gp`

---

## 2. 실행 — 두 가지 경로

### 2.1 WSL 셸에서 직접 (가장 단순)

```bash
bash /mnt/e/LTX-Kaggle/run_wan2gp.sh
```

`run_wan2gp.sh` 내용:

```bash
#!/usr/bin/env bash
set -e
cd /mnt/e/LTX-Kaggle/Wan2GP
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate wan2gp
python wgp.py --t2v-1-3B --profile 4 --attention sdpa --perc-reserved-mem-max 0.4 --listen --server-port 7860
```

옵션 의미:
- `--t2v-1-3B` — Wan 2.1 텍스트→비디오 1.3B 모델로 기동 (가장 가벼움, VRAM ~6GB)
- `--profile 4` — 기본 권장 메모리 프로파일 (모델 부분 로딩, 가장 유연)
- `--attention sdpa` — PyTorch 기본 어텐션 (Sage/Flash 미설치 환경에서 가장 안전)
- `--perc-reserved-mem-max 0.4` — 시스템 RAM 중 예약 영역을 40%까지 허용
- `--listen` — `0.0.0.0`에 바인딩(LAN/윈도우 호스트 모두 접근 가능)
- `--server-port 7860` — Gradio 포트

### 2.2 윈도우 측에서 더블클릭 (`run_wan2gp.bat`)

탐색기에서 `E:\LTX-Kaggle\run_wan2gp.bat` 더블클릭 또는 cmd에서:

```cmd
E:\LTX-Kaggle\run_wan2gp.bat
```

`run_wan2gp.bat` 내용:

```bat
@echo off
title WanGP
wsl.exe -e bash -lc "export PATH=/home/sharkey/anaconda3/bin:$PATH && /mnt/e/LTX-Kaggle/run_wan2gp.sh"
pause
```

핵심: `wsl.exe -e bash -lc`는 비대화형 셸이라 사용자 `.bashrc`의 conda 초기화가 안 들어옴 → PATH에 anaconda를 직접 export해서 `conda` 명령이 잡히도록 한 줄 추가했습니다. 그러고 나면 `run_wan2gp.sh`가 평소대로 동작합니다.

> 참고: 업스트림이 제공하는 `Wan2GP\scripts\run.bat`은 윈도우 측 `envs.json`을 요구합니다. 이 환경은 conda 환경이 WSL 쪽에만 있어 그 경로로는 동작하지 않습니다. 그래서 `run_wan2gp.bat` 래퍼를 사용합니다.

---

## 3. 브라우저 접속

기동 후 1\~3분 정도 모델 로딩이 끝나면 다음 주소가 응답합니다:

- 같은 윈도우 호스트: `http://localhost:7860/`
- 같은 LAN의 다른 기기: `http://<윈도우 호스트 IP>:7860/`

상태 확인:

```bash
# WSL에서
ss -tlnp | grep :7860              # LISTEN 상태 확인
curl -o /dev/null -s -w "%{http_code}\n" http://localhost:7860/   # 200이면 준비됨
```

---

## 4. 모델/인자 변경하기

세 가지 방식 중 골라 쓰면 됩니다.

| 방식 | 어디를 고치나 | 언제 쓰나 |
| --- | --- | --- |
| **A. `run_wan2gp.sh` 직접 편집** | `python wgp.py …` 줄의 인자 | 가장 직관적, 항상 같은 설정으로 띄울 때 |
| **B. `Wan2GP/scripts/args.txt`** | 한 줄(또는 여러 줄)로 인자 나열 | 공식 `scripts\run.bat`(윈도우 conda 설치 시) 경로에서 인자만 분리하고 싶을 때 |
| **C. 실행 직전 인자 추가** | `bash run_wan2gp.sh` 대신 직접 `python wgp.py --xxx` 실행 | 일회성 실험 |

자주 쓰는 인자 (전체 목록은 `Wan2GP/docs/CLI.md`):

```text
--t2v-1-3B / --t2v-14B / --i2v / --i2v-14B   # 시작 시 로드할 모델
--profile {1..5}                              # 메모리 프로파일 (기본 4, 24GB+면 3 고려)
--attention {sdpa|sage|sage2|flash}           # 어텐션 백엔드
--compile                                     # torch.compile (Triton 필요)
--teacache {1.5|1.75|2.0|2.25|2.5|0}          # TeaCache 가속 배율
--fp16                                        # bf16 대신 fp16 강제
--gpu cuda:1                                  # 다중 GPU 환경에서 특정 디바이스
--server-port 7860                            # Gradio 포트
--listen                                      # 외부 접근 허용 (0.0.0.0 바인딩)
--share                                       # HuggingFace 공유 링크 생성
--lock-config / --lock-model                  # 공개 인스턴스용 잠금
--advanced                                    # 시작 시 Advanced 옵션 펼친 상태
--lora-preset mystyle.lset                    # 로라 프리셋 사전 로드
```

---

## 5. 중지 / 재시작

```bash
# 어떤 wgp.py가 돌고 있는지
ps aux | grep wgp.py | grep -v grep

# 정상 종료
pkill -f "python wgp.py"

# Stopped(Tl) 상태로 끼어 응답 안 할 때 강제 종료
kill -9 <PID>

# 포트가 누가 잡고 있는지
ss -tlnp | grep :7860
```

알아둘 함정:
- WSL 콘솔을 Ctrl+Z로 잠시 멈춘 채 닫으면 프로세스가 `Tl`(Stopped) 상태로 남아 7860을 계속 점유합니다 → SIGTERM 안 먹혀서 `kill -9`로 죽여야 함. 이번 셋업 중에도 한 번 발생.

---

## 6. 스모크 테스트 (생성 1건 빠르게 확인)

설치/기동 점검용으로 한 번에 끝나는 생성을 돌릴 때:

```bash
# WSL
bash /mnt/e/LTX-Kaggle/test_wan2gp.sh
```
```cmd
:: 윈도우
E:\LTX-Kaggle\test_wan2gp.bat
```

동작:
1. 실행 중인 `python wgp.py`가 있으면 안전을 위해 중단(에러 메시지로 안내) — VRAM 충돌 방지
2. `Wan2GP/settings/test_smoke.json` 로드 → `--dry-run`으로 검증
3. 실제 생성 → `Wan2GP/outputs/`에 저장 (파일명에 timestamp + seed + prompt 첫 부분)
4. (윈도우) 결과 폴더를 탐색기로 자동 오픈

기본 테스트 프롬프트/파라미터는 `Wan2GP/settings/test_smoke.json`에서 수정 가능합니다.

- 1.3B 모델 + 25프레임 + 15스텝, 첫 실행은 모델 로딩 비용 때문에 15\~20분, 두 번째부터는 OS 페이지캐시로 단축됨
- 모델/스텝/해상도 바꾸면서 벤치마크하고 싶으면 `test_smoke.json`을 복사해서 새 파일 만들고 `test_wan2gp.sh` 안 `SETTINGS=` 변수만 바꾸면 됩니다

---

## 7. 헤드리스(배치) 실행

웹 UI 없이 저장된 큐/세팅을 처리:

```bash
cd /mnt/e/LTX-Kaggle/Wan2GP
conda activate wan2gp

# 큐 zip 처리
python wgp.py --process my_queue.zip --output-dir ./batch_out

# 세팅 json 1건 처리
python wgp.py --process settings.json --output-dir ./batch_out

# 실제 생성 없이 검증만
python wgp.py --process my_queue.zip --dry-run
```

웹 UI에서 "Save Queue"로 만든 zip을 그대로 쓰면 됩니다. 자세한 내용은 `Wan2GP/docs/CLI.md`.

---

## 8. 출력 / 작업 디렉터리

- 생성 결과: `Wan2GP/outputs/` (기본값, `wgp_config.json`의 `save_path`로 변경 가능)
- 모델 체크포인트 캐시: `Wan2GP/ckpts/` (gitignore됨, 자동 다운로드)
- 로라: `Wan2GP/loras/` 하위
- 사용자 세팅 저장: `Wan2GP/settings/`
- 런타임 설정: `Wan2GP/wgp_config.json` (UI에서 변경 시 자동 저장)

---

## 9. 트러블슈팅 체크리스트

| 증상 | 원인 / 해결 |
| --- | --- |
| `conda: command not found` (윈도우 `.bat` 실행 시) | `wsl.exe -e bash -lc`는 .bashrc 미적용 → 래퍼 안에서 `export PATH=/home/sharkey/anaconda3/bin:$PATH` 추가 (이미 적용됨) |
| 브라우저에서 "사이트에 연결할 수 없음" | 모델 로딩 중. 1\~3분 기다린 뒤 `ss -tln \| grep :7860`로 LISTEN 확인 후 새로고침 |
| 포트 7860 점유 충돌 (`Address already in use`) | 이전 `python wgp.py` 잔존. `pkill -f wgp.py` 또는 `kill -9 <PID>` |
| `python wgp.py` 시작하자마자 종료, "Incorrect version of mmgp" | `pip install -r requirements.txt`로 mmgp 버전 재맞춤 |
| OOM (VRAM 부족) | `--profile 4` 유지, `--attention sdpa`로 폴백, `--fp16`, `--teacache 2.0`로 가속 또는 더 작은 모델로 변경 |
| 윈도우 측 `scripts\run.bat`이 "No environments data found" | 윈도우에 conda/venv가 없어 그렇습니다. `run_wan2gp.bat` 래퍼를 사용하세요 |

---

## 10. 자주 쓰는 명령 한 줄 요약

```bash
# 시작 (WSL)
bash /mnt/e/LTX-Kaggle/run_wan2gp.sh

# 시작 (윈도우)
E:\LTX-Kaggle\run_wan2gp.bat

# 헬스 체크
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:7860/

# 종료
pkill -f "python wgp.py"

# 모델/인자 바꾸기
nano /mnt/e/LTX-Kaggle/run_wan2gp.sh
```

상세 문서는 `Wan2GP/docs/`(`CLI.md`, `MODELS.md`, `INSTALLATION.md`, `TROUBLESHOOTING.md`, `PROMPTS.md`)와 `Wan2GP/README.md`를 참조하세요.
