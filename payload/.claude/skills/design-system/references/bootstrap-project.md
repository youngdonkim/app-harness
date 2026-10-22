# 새 프로젝트에 이 시스템 도입하기

이 스킬은 하네스에 들어 있어서, 하네스를 적용한 프로젝트에서는 따로 복사할 필요 없이 바로 쓸 수 있다. 새 프로젝트에 이 디자인 시스템을 도입할 때는 아래 순서를 따른다. 스택은 Flutter + Material 3 고정이고, 지원 기기는 폰뿐이다.

**아래 코드는 모양을 보이는 견본이다.** 값은 자리표시자이고, 파일 이름·클래스 이름·`context.*` 이름은 고정이다 — 디자인 규칙 검사·목업 캔버스·앱 뼈대 틀이 이 이름을 그대로 쓴다. Flutter API는 판마다 이름이 바뀔 수 있으니(예: 옛 `textScaleFactor` → `TextScaler`, 옛 `MaterialStateProperty` → `WidgetStateProperty`) 도입할 때 그 판의 공식 API 문서와 `flutter analyze`의 경고로 맞춘다.

## 목차

0. [다른 곳에서 만든 시안·코드를 가져올 때](#0-다른-곳에서-만든-시안코드를-가져올-때)
1. [토큰 3층 구축 — Material 3 위에](#1-토큰-3층-구축--material-3-위에)
   - [1.1 순서](#11-순서)
   - [1.2 1층과 2층 파일의 모양](#12-1층과-2층-파일의-모양)
   - [1.3 ThemeData 조립과 접근 확장](#13-themedata-조립과-접근-확장)
   - [1.4 움직임 토큰과 동작 줄이기](#14-움직임-토큰과-동작-줄이기)
   - [1.5 대비 계산 도우미](#15-대비-계산-도우미)
   - [1.6 감싸개 부품과 누르는 크기](#16-감싸개-부품과-누르는-크기)
   - [1.7 글자 배율 검사 도우미](#17-글자-배율-검사-도우미)
2. [부품 인벤토리(사전) 생성](#2-부품-인벤토리사전-생성)
3. [프레임 정의](#3-프레임-정의)
4. [AGENTS.md에 프로젝트 연결 정보(adapter) 기록](#4-agentsmd에-프로젝트-연결-정보adapter-기록)
5. [다크 모드 대비 노트](#5-다크-모드-대비-노트)
6. [디자인 시스템 페이지](#6-디자인-시스템-페이지)
   - [6.1 보여 주는 것](#61-보여-주는-것)
   - [6.2 정본이 아니라 거울](#62-정본이-아니라-거울)
   - [6.3 비교안 값을 나란히 보이기](#63-비교안-값을-나란히-보이기)

---

## 0. 다른 곳에서 만든 시안·코드를 가져올 때

백지에서 시작하면 이 절은 건너뛰고 1로 간다. idea-to-mvp로 진행하는 프로젝트는 2단계부터 화면을 Flutter로 바로 짓기 때문에 이 절을 건너뛴다. 1단계 인터뷰의 예시 HTML은 참고 자료일 뿐 옮겨 오지 않는다.

외부 도구가 뽑은 시안(HTML·디자인 도구 내보내기·다른 Flutter 프로젝트의 화면)을 옮겨 오면, 화면과 함께 **"보여 주기용 틀"**까지 따라온다. 가져오는 날 한 번에 걷어 내는 편이 화면마다 뒤늦게 발견하는 것보다 훨씬 싸다.

- **가짜 기기 틀** — 폰 테두리·가짜 상태바(시계·배터리)·다이나믹 아일랜드·홈 막대 그림을 지운다. 그 자리를 비우려던 고정 여백도 지우고, 실제 기기의 안전 영역은 셸의 `SafeArea`가 맡는다 ([layout-frames.md](layout-frames.md) §4.3).
- **고정 화면 크기**(예: 390×844로 박힌 상자) — 지우고 셸이 받은 자리를 채우게 한다.
- **숫자 값** — 시안의 색·간격·글자 크기는 화면에 옮기지 않는다. 가까운 2층 이름으로 바꾸고, 맞는 것이 없으면 [naming-taxonomy.md](naming-taxonomy.md) §5로 토큰부터 더한다.
- **같은 모양의 반복** — 시안은 같은 버튼을 화면마다 따로 그려 둔다. 옮기면서 감싸개 부품 하나로 모은다(§1.6).
- **통째로 들어 있는 서체·그림** — 서체는 [font-loading.md](font-loading.md) 방식으로 다시 넣고, 그림은 `assets/`로 옮겨 `pubspec.yaml`에 등록한다.

## 1. 토큰 3층 구축 — Material 3 위에

```
lib/core/design/
  foundation.dart   ← 1층: 색 램프·간격 단위·글자 크기·둥글기·그림자·움직임 원본·서체 이름. 숫자·색을 쓰는 유일한 파일
  semantic.dart     ← 2층: ThemeExtension 여덟 개(AppColors·AppSpace·AppLayout·AppRadius·AppTextStyles·AppShadows·AppMotion
                      ·AppBrand — 마지막은 2-3 개성 입히기가 쓰는 자리라 처음엔 「없음」 값)
                      + 그 묶음 AppTokens. 값은 전부 1층 상수만 가리킨다
  theme.dart        ← 3층 조립: AppTokens → ThemeData (ColorScheme·TextTheme·부품 테마·extensions)
  tokens.dart       ← 접근 확장: context.colors · context.space · context.layout · context.radius
                      · context.text · context.shadows · context.motion (동작 줄이기 처리 포함) · context.brand
  contrast.dart     ← 대비 계산 도우미 (§1.5)
  drafts.dart       ← 비교안 값 자리 — 평소엔 비어 있다 (§6.3)
  design.dart       ← 화면·부품이 import하는 한 파일. semantic·tokens·contrast만 내보내고 foundation은 내보내지 않는다
lib/shared/components/ui/       ← 3층 부품(범용): Material 감싸개 (AppButton·AppTextField …)
lib/shared/components/common/   ← 3층 부품(전용, 여러 흐름 공통)
lib/features/<흐름>/widgets/    ← 3층 부품(전용, 그 흐름만)
test/core/design/contrast_test.dart   ← 2층 색 짝 대비 검사 (§1.5)
test/helpers/text_scale.dart          ← 글자 배율 검사 도우미 (§1.7)
```

### 1.1 순서

1. **1층 `foundation.dart`** — 채택한 브랜드(또는 참고에서 뽑은 값 — [reference-analysis.md](reference-analysis.md) §5)의 원시 값을 채운다. 색은 `Color(0xFF…)` 램프, 간격은 4 단위, 글자 크기·줄 높이, 둥글기 기준, 그림자, 움직임 길이·곡선, 서체 이름. 이 층은 읽기 전용 취급 — 이후 브랜드가 바뀌면 통째로 교체한다.
   - **서체 선정 + 넣는 방식도 이 단계에서 함께** 한다. 색만 정하고 서체를 뒤로 미루면 나중에 foundation을 다시 갈아엎게 된다 ([font-loading.md](font-loading.md)).
2. **2층 `semantic.dart`** — 여덟 확장을 1층 상수로 채운다(§1.2). 여덟째 `AppBrand`는 브랜드 색 면과 사진 보정 값이 들어갈 자리이고, 개성을 입히기 전(2-3 전)에는 기본 묶음 `AppBrand.none`(면 색은 `surface`와 같고 사진 보정은 0)으로 둔다. 색 이름은 Material `ColorScheme` 이름을 따르고, 우리가 더하는 역할도 같은 문법으로 짓는다.
3. **3층 조립 `theme.dart`** — 2층으로 `ThemeData`를 만든다(§1.3). Material 부품 테마(버튼·입력칸·카드·하단 탭·상단 바·칩·대화상자·시트·알림 띠)를 여기서 2층 값으로 맞추면, Material 부품이 화면 코드 수정 없이 브랜드 모양으로 돈다.
4. **접근 확장 `tokens.dart`와 내보내기 `design.dart`** — 화면이 2층에 닿는 길을 하나로 만든다(§1.3).
5. **대비 도우미 `contrast.dart`와 대비 테스트** — 2층 글자색·바탕색 짝이 기준 이상인지 단위 테스트로 건다(§1.5).
6. **감싸개 부품** — 버튼·입력칸처럼 variant와 누르는 크기가 걸린 부품을 `lib/shared/components/ui/`에 만든다(§1.6).
7. **글자 배율 도우미** — 화면마다 글자 배율 2.0 위젯 테스트를 걸 도우미를 둔다(§1.7).
8. **비교안 자리 `drafts.dart`** — 빈 파일을 머리 주석 한 줄(`// 비교안 — 화면 개선 비교 동안만. bootstrap-project.md §6.3`)과 함께 만들어 둔다. 화면 개선 단계(idea-to-mvp 2-2)가 여기에 비교안 값을 넣고, 고른 뒤 비운다. 2-3 개성 입히기처럼 판이 여럿이면 판마다 파일을 따로 쓰고 이 파일에는 `export` 줄만 둔다(§6.3) — 자리가 처음부터 있어야 비교안 값이 2층 본 값 사이로 섞여 들어가지 않는다.

### 1.2 1층과 2층 파일의 모양

값은 자리표시자다.

```dart
// lib/core/design/foundation.dart — 1층. 숫자·색 값을 쓸 수 있는 유일한 파일.
// 화면·부품은 이 파일을 import하지 않는다 (semantic.dart만 읽는다).
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

abstract final class Palette {
  static const gray0 = Color(0xFFFFFFFF);
  static const gray50 = Color(0xFFF7F8FA);
  static const gray100 = Color(0xFFEEF0F3);
  static const gray200 = Color(0xFFE1E4E8);
  static const gray500 = Color(0xFF8B95A1);
  static const gray600 = Color(0xFF6B7684);
  static const gray900 = Color(0xFF191F28);
  static const brand50 = Color(0xFFEEF5FF);
  static const brand600 = Color(0xFF3182F6);
  static const brand800 = Color(0xFF1B64DA);
  static const green600 = Color(0xFF15803D);
  static const amber700 = Color(0xFFB45309);
  static const red600 = Color(0xFFDC2626);
  // … 램프마다 50~950
}

abstract final class FoundationSpace {
  static const double unit = 4; // 모든 간격은 이 단위의 배수
}

abstract final class FoundationType {
  static const String family = 'Pretendard'; // pubspec.yaml의 family 이름 (font-loading.md)
  static const String titleFamily = family;  // 제목 서체 — 2-3 개성 입히기가 따로 고르기 전에는 family와 같다
  static const double t1 = 30, t2 = 26, h1 = 22, h2 = 20, h3 = 18;
  static const double b1 = 16, b2 = 14, label = 15, caption = 12;
  static const double lineTight = 1.3, lineBody = 1.6; // 줄 높이 배수
  static const double trackingTitle = -0.02; // 큰 제목 자간 (글자 크기 대비 비율)
}

abstract final class FoundationRadius {
  static const double base = 16; // 카드 둥글기. 나머지는 2층이 여기서 파생
  static const double pill = 999;
}

abstract final class FoundationShadow {
  static const cardColor = Color(0x14000000);
  static const double cardBlur = 16, cardY = 2;
}

abstract final class FoundationMotion {
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 320);
  static const curveOut = Cubic(0.2, 0, 0, 1); // 끝에서 부드럽게 멈춤
  static const curveSpring = Cubic(0.34, 1.56, 0.64, 1); // 끝에서 살짝 튐 — 생동감이 필요할 때만
}

abstract final class FoundationSize {
  static const double touchMin = 48; // 누르는 영역 바닥선 (dp — 화면 밀도와 무관한 길이 단위)
  static const double screenX = 20; // 화면 좌우 여백
}
```

```dart
// lib/core/design/semantic.dart — 2층. 값은 전부 foundation 상수만 가리킨다.
import 'package:flutter/material.dart';
import 'foundation.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary, required this.onPrimary,
    required this.primaryContainer, required this.onPrimaryContainer,
    required this.surface, required this.onSurface, required this.onSurfaceVariant,
    required this.subtle, // 희미한 글자 — Material에 없는 셋째 단계
    required this.surfaceContainerLow, required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.outline, required this.outlineVariant,
    required this.error, required this.onError,
    required this.success, required this.onSuccess,
    required this.warning, required this.onWarning,
    required this.scrim, required this.inverseSurface, required this.onInverseSurface,
  });

  final Color primary, onPrimary, primaryContainer, onPrimaryContainer;
  final Color surface, onSurface, onSurfaceVariant, subtle;
  final Color surfaceContainerLow, surfaceContainer, surfaceContainerHigh;
  final Color outline, outlineVariant, error, onError;
  final Color success, onSuccess, warning, onWarning;
  final Color scrim, inverseSurface, onInverseSurface;

  static const light = AppColors(
    primary: Palette.brand600, onPrimary: Palette.gray0,
    primaryContainer: Palette.brand50, onPrimaryContainer: Palette.brand800,
    surface: Palette.gray0, onSurface: Palette.gray900,
    onSurfaceVariant: Palette.gray600, // 보조 글자 — 바탕과 4.5:1 이상
    subtle: Palette.gray500,           // 희미한 글자 — 바탕과 4.5:1 이상 (대비 테스트가 확인)
    surfaceContainerLow: Palette.gray50, surfaceContainer: Palette.gray100,
    surfaceContainerHigh: Palette.gray200,
    outline: Palette.gray500, outlineVariant: Palette.gray200,
    error: Palette.red600, onError: Palette.gray0,          // 상태 의미 전용, 장식 금지
    success: Palette.green600, onSuccess: Palette.gray0,
    warning: Palette.amber700, onWarning: Palette.gray0,
    scrim: Palette.gray900, inverseSurface: Palette.gray900, onInverseSurface: Palette.gray0,
  );

  /// 대비를 확인할 글자·바탕 짝. 대비 테스트와 디자인 시스템 페이지가 이 목록을 함께 쓴다 (§1.5).
  List<(String, Color, Color, double)> get contrastPairs => [
        ('onSurface / surface', onSurface, surface, 4.5),
        ('onSurfaceVariant / surface', onSurfaceVariant, surface, 4.5),
        ('subtle / surface', subtle, surface, 4.5),
        ('onPrimary / primary', onPrimary, primary, 4.5),
        ('onPrimaryContainer / primaryContainer', onPrimaryContainer, primaryContainer, 4.5),
        ('onError / error', onError, error, 4.5),
        ('onSuccess / success', onSuccess, success, 4.5),
        ('onWarning / warning', onWarning, warning, 4.5),
        ('primary / surface (선·포커스)', primary, surface, 3.0),
      ];

  @override
  AppColors copyWith({Color? primary, Color? onPrimary /* … 필드마다 하나 */}) => AppColors(
        primary: primary ?? this.primary, onPrimary: onPrimary ?? this.onPrimary,
        // … 필드마다 같은 줄
      );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      // … 필드마다 같은 줄
    );
  }
}

@immutable
class AppSpace extends ThemeExtension<AppSpace> {
  // 이름의 숫자 = 4의 배수 (s4 = 16). 화면이 쓸 단계는 프로젝트 「화면 규칙」 허용 목록이 고른다.
  const AppSpace({required this.s1, required this.s2, required this.s3, required this.s4,
      required this.s5, required this.s6, required this.s8, required this.s10,
      required this.s12, required this.s16});
  final double s1, s2, s3, s4, s5, s6, s8, s10, s12, s16;

  static const regular = AppSpace(
    s1: FoundationSpace.unit * 1, s2: FoundationSpace.unit * 2, s3: FoundationSpace.unit * 3,
    s4: FoundationSpace.unit * 4, s5: FoundationSpace.unit * 5, s6: FoundationSpace.unit * 6,
    s8: FoundationSpace.unit * 8, s10: FoundationSpace.unit * 10, s12: FoundationSpace.unit * 12,
    s16: FoundationSpace.unit * 16,
  );
  // copyWith·lerp — AppColors와 같은 모양 (lerpDouble)
}

// AppLayout   — 프레임 예산: screenX(화면 좌우 여백) · touchMin(누르는 영역 바닥선) · bottomBarGap 등
// AppRadius   — base · control · card · sheet · pill + inner() 도우미 (naming-taxonomy.md §4)
// AppTextStyles — t1 t2 h1 h2 h3 b1 b2 label caption + display (TextStyle). caption은 그림 위 글자 전용.
//   display는 2-3 개성 입히기의 전시용 제목 한 단계 — 대표 장면 한 곳에서만 쓰고, 본 값은 t1과 같게 먼저 둔다(= 없음)
// AppShadows  — card · sheet (List<BoxShadow>)
// AppMotion   — fast · base · slow (Duration) + standard · emphasis (Curve) + reduced() (§1.4)
// 모두 같은 모양: const 생성자 + static const 기본 묶음 + copyWith + lerp.

/// 사진 보정 값 — 사진 파일은 고치지 않고 밝기·채도·따뜻함만 조금 바꾼다(visual-polish.md I5). 모두 0이면 보정 없음.
@immutable
class PhotoTone {
  const PhotoTone({required this.brightness, required this.saturation, required this.warmth});
  final double brightness, saturation, warmth; // 0 = 원본 그대로, 양수·음수 = 그만큼 더·덜
  static const none = PhotoTone(brightness: 0, saturation: 0, warmth: 0);
}

/// 브랜드 색 면과 사진 보정 값을 모은 여덟째 확장 (SKILL.md 「브랜드 색은 어디에 쓰나」).
/// 기본 묶음 [none] 은 「없음」이다 — 면 색은 AppColors.light.surface 와 같은 1층 값이고 사진 보정은 0이라
/// 화면이 지금과 달라지지 않는다. 2-3 개성 입히기가 고른 값을 여기에 앉힌다.
@immutable
class AppBrand extends ThemeExtension<AppBrand> {
  const AppBrand({required this.surface, required this.onSurface, required this.onSurfaceMuted,
      required this.photoTone});
  final Color surface, onSurface; // 브랜드 색 면과 그 위 글자
  final Color onSurfaceMuted; // 면 위 회색 글자 짝 — 본 값은 onSurfaceVariant와 같게(= 없음)
  final PhotoTone photoTone;

  static const none = AppBrand(
      surface: Palette.gray0, onSurface: Palette.gray900, onSurfaceMuted: Palette.gray600,
      photoTone: PhotoTone.none);
  // copyWith·lerp — AppColors와 같은 모양
}

/// 여덟 확장을 한 벌로 묶은 것. theme.dart가 이걸로 ThemeData를 만들고, 비교안은 copyWith로 일부만 바꾼다.
@immutable
class AppTokens {
  const AppTokens({required this.colors, required this.space, required this.layout,
      required this.radius, required this.text, required this.shadows, required this.motion,
      required this.brand});
  final AppColors colors; final AppSpace space; final AppLayout layout; final AppRadius radius;
  final AppTextStyles text; final AppShadows shadows; final AppMotion motion; final AppBrand brand;

  static final light = AppTokens(colors: AppColors.light, space: AppSpace.regular,
      layout: AppLayout.regular, radius: AppRadius.regular, text: AppTextStyles.regular,
      shadows: AppShadows.light, motion: AppMotion.regular,
      brand: AppBrand.none); // 2-3 개성 입히기가 고른 뒤에야 진짜 값이 된다 — 디자인 규칙 검사 17번이 이 줄을 읽는다

  AppTokens copyWith({AppColors? colors, AppSpace? space, AppBrand? brand /* … */}) => AppTokens(
      colors: colors ?? this.colors, space: space ?? this.space, brand: brand ?? this.brand, /* … */
      layout: layout, radius: radius, text: text, shadows: shadows, motion: motion);

  /// 대비를 확인할 짝 전부 — 색 짝(§1.5) + 브랜드 짝. 브랜드를 아직 안 들였으면(none) 브랜드 짝은 빼서
  /// 「면과 바탕 1.2:1」이 같은 값끼리 재다 실패하지 않게 한다.
  List<(String, Color, Color, double)> get contrastPairs => [
        ...colors.contrastPairs,
        if (!identical(brand, AppBrand.none)) ...[
          ('브랜드 면 / 바탕', brand.surface, colors.surface, 1.2),
          ('onSurface(브랜드) / 브랜드 면', brand.onSurface, brand.surface, 4.5),
          ('onSurfaceMuted(브랜드) / 브랜드 면 (면 위 회색 글자)', brand.onSurfaceMuted, brand.surface, 4.5),
          ('onPrimary / 브랜드 면 (면 위 주 버튼)', colors.onPrimary, brand.surface, 3.0),
        ],
      ];
}
```

- **`AppBrand`가 따로 있는 이유** — 브랜드 면 색 두 개만이면 `AppColors`에 더해도 되지만, 사진 보정 값이 갈 곳이 없어 확장이 어차피 하나 더 생긴다. 한 묶음이면 「들였나」 판정(검사 17번이 `AppTokens.light`의 `brand`가 `AppBrand.none`인지 읽는다)·비교안 바꾸기(`copyWith(brand: …)` 한 줄)·고른 뒤 옮기기가 모두 한 줄이다.
- **새 이름은 본 값 「없음」으로 먼저 둔다** — `AppBrand.onSurfaceMuted`·`AppTextStyles.display`처럼 개성 입히기가 처음 쓰는 이름은 지금 값과 같게 본 파일에 먼저 만들어 둔다(`onSurfaceMuted`는 `onSurfaceVariant`와 같게, `display`는 `t1`과 같게). 그래야 판 토큰 파일이 `copyWith`로 진짜 값을 얹어도 본 화면이 달라지지 않는다. 공유 파일 준비가 한다.
- **간격·둥글기·글자까지 `ThemeExtension`에 두는 이유** — 값이 테마를 따라 흐르기 때문이다. 비교안 화면을 `Theme`으로 감싸면 그 아래 `context.space.s4`가 비교안 값을 읽는다(§6.3). `const` 전역 상수로 두면 이 덮개가 안 통한다.
- **글자 단계 이름은 고정이다** — `t1`·`t2`(큰 제목) · `h1`·`h2`·`h3`(화면·묶음 제목) · `b1`·`b2`(본문) · `label`(버튼·입력 라벨) · `caption`(그림 위 글자 전용). 프로젝트는 크기 값만 바꾼다. `caption`을 뺀 모든 단계는 글자 크기 바닥선(14) 이상이다.
- **글자 스타일에 색을 넣지 않는다** — 글자색은 바탕에 따라 다르니 쓰는 자리에서 `context.text.b2.copyWith(color: context.colors.onSurfaceVariant)`처럼 2층 색을 준다. `copyWith`로 바꿔도 되는 것은 색과 굵기(`FontWeight.w400`·`w500`·`w700` — 앱에 넣은 굵기만)뿐이다.

### 1.3 ThemeData 조립과 접근 확장

```dart
// lib/core/design/theme.dart — 3층 조립. 2층 값으로 Material 전체의 기본 모양을 정한다.
import 'package:flutter/material.dart';
import 'semantic.dart';

ThemeData buildAppTheme(AppTokens t, {Brightness brightness = Brightness.light}) {
  final c = t.colors;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.primary, onPrimary: c.onPrimary,
    primaryContainer: c.primaryContainer, onPrimaryContainer: c.onPrimaryContainer,
    // secondary·tertiary는 두 번째 강조색이 되지 않게 강조색 계열로 잇는다 (SKILL.md 「강조색은 어디에 쓰나」).
    // Material 3는 하단 탭 선택 표시·고른 칩에 secondaryContainer를 쓴다.
    secondary: c.primary, onSecondary: c.onPrimary,
    secondaryContainer: c.primaryContainer, onSecondaryContainer: c.onPrimaryContainer,
    tertiary: c.primary, onTertiary: c.onPrimary,
    error: c.error, onError: c.onError,
    surface: c.surface, onSurface: c.onSurface, onSurfaceVariant: c.onSurfaceVariant,
    surfaceContainerLow: c.surfaceContainerLow, surfaceContainer: c.surfaceContainer,
    surfaceContainerHigh: c.surfaceContainerHigh,
    outline: c.outline, outlineVariant: c.outlineVariant,
    scrim: c.scrim, inverseSurface: c.inverseSurface, onInverseSurface: c.onInverseSurface,
    surfaceTint: c.surface, // 떠 있는 면에 강조색 기운이 섞이지 않게
  );
  final text = t.text;
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: c.surface,
    fontFamily: text.b1.fontFamily,
    materialTapTargetSize: MaterialTapTargetSize.padded, // 작은 부품도 누르는 영역 48dp
    textTheme: TextTheme(
      displayLarge: text.t1, displayMedium: text.t2, displaySmall: text.h1,
      headlineLarge: text.h1, headlineMedium: text.h2, headlineSmall: text.h3,
      titleLarge: text.h2, titleMedium: text.h3, titleSmall: text.b1,
      bodyLarge: text.b1, bodyMedium: text.b2, bodySmall: text.b2,   // Material 기본 12를 바닥선으로 올린다
      labelLarge: text.label, labelMedium: text.b2, labelSmall: text.b2,
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      minimumSize: Size(0, t.layout.touchMin),
      textStyle: text.label,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radius.control)),
    )),
    // outlinedButtonTheme · textButtonTheme · inputDecorationTheme · cardTheme(그림자 0, surfaceContainerLow,
    // radius.card) · navigationBarTheme(indicatorColor: primaryContainer) · appBarTheme · chipTheme ·
    // dialogTheme · bottomSheetTheme(radius.sheet) · snackBarTheme · dividerTheme 를 같은 식으로.
    extensions: [c, t.space, t.layout, t.radius, text, t.shadows, t.motion, t.brand],
  );
}
```

```dart
// lib/core/design/tokens.dart — 화면이 2층에 닿는 유일한 길.
import 'package:flutter/material.dart';
import 'semantic.dart';

extension DesignTokens on BuildContext {
  ThemeData get _theme => Theme.of(this);
  AppColors get colors => _theme.extension<AppColors>()!;
  AppSpace get space => _theme.extension<AppSpace>()!;
  AppLayout get layout => _theme.extension<AppLayout>()!;
  AppRadius get radius => _theme.extension<AppRadius>()!;
  AppTextStyles get text => _theme.extension<AppTextStyles>()!;
  AppShadows get shadows => _theme.extension<AppShadows>()!;
  AppBrand get brand => _theme.extension<AppBrand>()!;

  /// 움직임 값. 시스템 「동작 줄이기」가 켜져 있으면 길이를 0으로 돌려준다 — 전역 장치는 여기 한 곳 (§1.4).
  AppMotion get motion {
    final m = _theme.extension<AppMotion>()!;
    return MediaQuery.disableAnimationsOf(this) ? m.reduced() : m;
  }
}
```

```dart
// lib/core/design/design.dart — 화면·부품은 이 파일 하나만 import한다.
export 'contrast.dart';
export 'semantic.dart';
export 'tokens.dart';
// foundation.dart는 내보내지 않는다.
```

- **앱 시작 자리** — `MaterialApp.router(theme: buildAppTheme(AppTokens.light), …)`. 진입점이 셋(`main_dev`·`main_prod`·`main_canvas`)이어도 테마는 이 한 줄로 같다.
- **Material 이름과 우리 이름이 `context.colors` 한 묶음에 있다** — 그래서 화면은 `Theme.of(context).colorScheme`을 부를 일이 없다(디자인 규칙 검사 7번). `ColorScheme`은 Material 부품이 읽으라고 `theme.dart`가 `AppColors`에서 채워 주는 사본이다.
- **2층 이름을 더하면 세 곳을 함께 고친다** — `semantic.dart`의 필드·`copyWith`·`lerp`, Material 부품이 읽어야 하면 `theme.dart`, 대비가 걸리면 `contrastPairs`. 확장 묶음을 새로 더하면(`AppBrand`처럼) `theme.dart`의 `extensions` 목록과 `tokens.dart`의 접근 이름도 더한다.

### 1.4 움직임 토큰과 동작 줄이기

움직임 값도 색처럼 1층 기본 값 → 2층 이름으로 전달된다. 길이 세 단계(빠름·보통·느림)와 가속 곡선 둘이면 충분하다. 값 몇 개만 바꾸면 앱 전체 움직임의 느낌이 같이 바뀌게 하려는 것이다. 이름은 [naming-taxonomy.md](naming-taxonomy.md) 유형표 motion 행을 따른다. 값은 자리표시자다 — idea-to-mvp 3단계면 `mvp/design-brief.md` 「8. 모션·인터랙션 방향」의 분석 결과로 채운다.

```dart
// semantic.dart 안
@immutable
class AppMotion extends ThemeExtension<AppMotion> {
  const AppMotion({required this.fast, required this.base, required this.slow,
      required this.standard, required this.emphasis});
  final Duration fast, base, slow;
  final Curve standard, emphasis;

  static const regular = AppMotion(fast: FoundationMotion.fast, base: FoundationMotion.base,
      slow: FoundationMotion.slow, standard: FoundationMotion.curveOut,
      emphasis: FoundationMotion.curveSpring);

  /// 동작 줄이기 — 길이만 0으로. 곡선은 그대로 둔다(길이가 0이면 곡선은 의미가 없다).
  AppMotion reduced() => copyWith(fast: Duration.zero, base: Duration.zero, slow: Duration.zero);
  // copyWith · lerp(길이·곡선은 t < 0.5 ? this : other)
}
```

- **화면·부품은 `context.motion.base`·`context.motion.standard`만 쓴다** — `Duration(milliseconds: 300)`·`Curves.easeOut`을 적지 않는다(디자인 규칙 검사 9번).
- **동작 줄이기(시스템 설정에서 움직임을 줄여 달라고 켜 둔 사람)** — 화면마다 분기하지 않는다. `context.motion`이 `MediaQuery.disableAnimationsOf`를 읽어 길이를 0으로 돌려주는 한 곳에서 처리한다(검사 8번). `AnimationController`에 0 길이를 주면 바로 끝 값으로 간다. 반복 움직임(돌기·떠다니기처럼 끝없이 도는 `AnimationController.repeat`)은 길이가 0이어도 멈추지 않으니, 동작 줄이기(`MediaQuery.disableAnimationsOf`)일 때는 시작하지 않고 첫 모습으로 둔다. 시작 전 지연(`Future.delayed`·`Interval`의 시작 시점)도 0으로 한다.
- **Material 부품 자체의 움직임**(화면 넘김·물결 효과)이 그 설정을 따르는지는 판마다 다를 수 있다 — 도입 때 실측하고, 따르지 않는 것이 거슬리면 `theme.dart`에서 그 부품 테마로 맞춘다.

### 1.5 대비 계산 도우미

글자색과 바탕색의 대비(WCAG — 웹 접근성 국제 기준. 글자 4.5:1, 큰 글자·선·아이콘 3:1)를 숫자로 계산하는 작은 도우미다. 화면을 보지 않고 숫자로 거를 수 있는 몇 안 되는 디자인 검사라, 2층 색을 바꿀 때마다 테스트가 잡는다.

```dart
// lib/core/design/contrast.dart
import 'dart:math' as math;
import 'dart:ui';

const double kContrastText = 4.5;  // 본문 글자
const double kContrastLarge = 3.0; // 큰 글자(대략 h1 이상)·선·아이콘·포커스 표시

/// WCAG 대비 = (밝은 쪽 휘도 + 0.05) / (어두운 쪽 휘도 + 0.05).
/// 반투명 글자색이면 먼저 바탕에 합쳐서 넘긴다: Color.alphaBlend(fg, bg).
double contrastRatio(Color fg, Color bg) {
  final a = fg.computeLuminance();
  final b = bg.computeLuminance();
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}
```

```dart
// test/core/design/contrast_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:<앱>/core/design/design.dart';

void main() {
  for (final (name, fg, bg, min) in AppTokens.light.contrastPairs) {
    test('대비 $name ≥ $min', () => expect(contrastRatio(fg, bg), greaterThanOrEqualTo(min)));
  }
}
```

- **어디에 쓰나** — ① 대비 테스트(위) ② 2-2 화면 개선에서 색을 바꿔 볼 때 ③ 디자인 시스템 페이지가 색 짝마다 대비 숫자를 보여 줄 때(§6.1) ④ 참고에서 뽑은 강조색을 램프에 잇는 단계를 고를 때([reference-analysis.md](reference-analysis.md) §5).
- **짝 목록(`contrastPairs`)이 정본이다** — 새 `on` 짝을 더하면 목록에도 한 줄 더한다. 목록에 없는 짝은 아무도 재지 않는다. 색 짝은 `AppColors`가, 브랜드 짝(면과 바탕 1.2 · 면 위 글자 4.5 · 면 위 회색 글자 4.5 · 면 위 주 버튼 3.0)은 `AppTokens`가 묶어 낸다 — 브랜드를 아직 안 들였으면 브랜드 짝은 목록에서 빠진다. 질감·그라데이션 면은 면의 가장 나쁜 자리(가장 어둡거나 밝은 곳)의 색을 짝에 넣어 잰다.
- **다크 모드를 만들면** 같은 테스트를 다크 묶음(`AppTokens.dark`)에도 돌린다.

### 1.6 감싸개 부품과 누르는 크기

웹의 「받아 와서 고쳐 쓰는 부품 모음」 자리는 **Material 감싸개**다. Material 부품은 테마로 모양을 거의 다 바꿀 수 있어 받아 와서 고칠 파일이 없다. 대신 variant와 누르는 크기가 걸린 부품은 우리 감싸개를 거치게 해 화면마다 다르게 쓸 틈을 없앤다.

- **반드시 감싸개를 거치는 부품** — 버튼(`AppButton`), 입력칸(`AppTextField`), 그 밖에 variant가 둘 이상이거나 누르는 크기를 우리가 정해야 하는 것(칩·고르기 칸·대화상자 등 — 생길 때 정한다).
- **Material 것을 바로 써도 되는 부품** — 목록 행(`ListTile`)·카드(`Card`)·구분선·진행 표시처럼 테마만으로 충분한 것. 단 화면에서 `style:`·`color:`·`shape:`·숫자 `padding:`으로 겉모양을 덮어쓰지 않는다.

```dart
// lib/shared/components/ui/app_button.dart
// 앱의 모든 버튼. 주 버튼(primary)은 한 화면에 하나 — SKILL.md 「강조색은 어디에 쓰나」.
import 'package:flutter/material.dart';
import '../../../core/design/design.dart';

enum AppButtonVariant { primary, secondary, text, danger }

class AppButton extends StatelessWidget {
  const AppButton({super.key, required this.variant, required this.label,
      required this.onPressed, this.icon, this.expand = false});
  final AppButtonVariant variant; // 기본값 없음 — 주 버튼이 늘 글자로 찍히게 (디자인 규칙 검사 10번)
  final String label;
  final VoidCallback? onPressed; // null이면 비활성
  final IconData? icon;
  final bool expand;             // 폭을 꽉 채울지 — 배치는 화면이 고른다

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final child = Text(label, maxLines: 2, textAlign: TextAlign.center); // 큰 글자에서 두 줄 허용
    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(onPressed: onPressed, child: child),
      AppButtonVariant.secondary => OutlinedButton(onPressed: onPressed, child: child),
      AppButtonVariant.text => TextButton(onPressed: onPressed, child: child),
      AppButtonVariant.danger => FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(backgroundColor: c.error, foregroundColor: c.onError),
          child: child),
    };
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
```

- **누르는 영역은 48dp 이상**(`context.layout.touchMin`, idea-to-mvp는 `mvp/design-brief.md` 「9. 접근성 바닥선」이 정한 값). 버튼 테마의 `minimumSize`와 `materialTapTargetSize: padded`가 맡는다. 보이는 크기를 키우면 어색한 부품(체크 상자 등)은 보이는 크기를 두고 누르는 영역만 넓힌다.
- **높이는 「최소」로만 정한다** — 글자 배율에서 버튼이 커질 수 있어야 한다(SKILL.md 「글자 배율 규칙」 1).
- **작은 크기 variant도 같은 바닥선이다** — 누르는 요소에 바닥선 밑 크기를 두지 않는다.
- **부품 모양 값이 바닥선과 부딪히면 바닥선이 이긴다** — 예: 브리프의 부품 모양에 「버튼 높이 40」이 있고 바닥선이 48이면 48로 만들고, 부딪힌 것을 보고에 적어 사람이 브리프를 고치게 한다.
- **감싸개 안은 디자인 규칙 검사 대상이 아니다** — Material의 `style:`을 만지는 것이 감싸개의 일이라서다. 그래도 값은 2층 이름으로만 쓴다(철칙 1·2는 감싸개에도 그대로).

### 1.7 글자 배율 검사 도우미

화면마다 「글자 배율 2.0에서 넘침이 없다」를 위젯 테스트로 건다. Flutter 위젯 테스트는 넘침(`RenderFlex overflowed`) 오류가 나면 실패한다.

```dart
// test/helpers/text_scale.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:<앱>/core/design/theme.dart';
import 'package:<앱>/core/design/semantic.dart';

/// [screen]을 보통 폰 크기·글자 배율 [scale]로 그린다. 넘침이 있으면 테스트가 실패한다.
Future<void> pumpAtTextScale(WidgetTester tester, Widget screen,
    {double scale = 2.0, Size size = const Size(360, 780)}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(AppTokens.light),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: screen,
  ));
  await tester.pumpAndSettle();
}
```

- **화면을 그리는 데 필요한 것**(가짜 저장소 provider 덮어쓰기·문구 파일·라우터)은 앱 뼈대와 목업 캔버스가 쓰는 가짜 저장소를 그대로 쓴다 — 이 도우미는 그 바깥을 감싸는 자리만 정한다. 도우미의 실제 모양은 앱 뼈대를 만들 때 맞춘다.
- **크기 `360`은 작은 폰 폭**이다([layout-frames.md](layout-frames.md) §4.1). 넘침은 작은 폭에서 먼저 난다.
- **골든 테스트(화면을 그림으로 찍어 기준 그림과 비교하는 테스트)와 다르다** — 이 테스트는 그림을 비교하지 않고 넘침 오류만 본다. 그래서 CI에서도 돈다.

## 2. 부품 인벤토리(사전) 생성

프로젝트 문서 `docs/components.md`에 새로 작성한다:
- 등록 단위는 **부품 파일**이다. 구분은 둘 — 범용(`lib/shared/components/ui/` — 감싸개)과 전용(`lib/shared/components/common/`·`lib/features/*/widgets/`)
- §1.6에서 만든 감싸개와 셸 부품을 등록하고, 앞으로 만드는 부품은 그때마다 등록한다
- 문서 끝에 「## 전체 부품 색인」 구간까지 만든다 — 부품을 더하거나 지울 때마다 다시 만든다
- 형식·규칙은 [component-taxonomy.md](component-taxonomy.md) §6

## 3. 프레임 정의

frame-first로 셸·영역·크기 예산을 먼저 정하고, 예산은 2층 `AppLayout`에 적는다 ([layout-frames.md](layout-frames.md)).
- 셸은 `lib/app/shell.dart`. 하단 탭이 있으면 go_router의 셸 경로(`StatefulShellRoute` — 탭마다 화면 쌓임을 따로 지키는 경로 묶음)가 이 셸을 감싼다.
- 화면 아래에 늘 보여야 하는 요소(주 행동 버튼 막대·탭바 등)의 자리도 이때 정한다 — 공통 셸은 하단 고정 요소가 아직 없어도 상단/본문/하단 세 영역으로 시작한다 ([layout-frames.md](layout-frames.md) §2.2).
- 작은 폰·큰 폰의 예산(화면 좌우 여백·목록 한 줄 높이)과 안전 영역을 셸이 맡는 범위를 이때 정한다 ([layout-frames.md](layout-frames.md) §4).

## 4. AGENTS.md에 프로젝트 연결 정보(adapter) 기록

스킬은 범용, 프로젝트는 제각각 — 둘을 이어 주는 **이 프로젝트만의 연결 정보**를 AGENTS.md 「디자인 시스템 연결 정보」 절에 기록한다:
- 토큰 파일 경로(`lib/core/design/`의 여섯 파일 + `design.dart`)와 앱 패키지 이름(import 경로 `package:<앱>/…`)
- 부품 인벤토리 위치(`docs/components.md`)와 부품 폴더 세 곳(`lib/shared/components/ui/`·`common/`·`lib/features/*/widgets/`)
- 프레임 인벤토리·화면 패턴 목록 위치
- **감싸개 부품 목록** — `ui/`에 둔 감싸개와 그 부품이 감싸는 Material 부품 한 줄씩(예: `AppButton — FilledButton·OutlinedButton·TextButton`). 「이 부품은 Material 것을 바로 쓰지 말고 감싸개로」를 쓰는 쪽이 알게 하는 목록이다
- 디자인 규칙 검사 예외 줄 — 검사에 걸리지만 남길 값과 이유(예: `Colors.transparent` 한 곳, 그림 위 글자에 쓰는 `caption`, 한 부품에만 둔 글자 배율 상한)와 프로젝트 고유 함정 토큰
- 철칙 요약 (짧게 — 항상 컨텍스트에 있어야 하는 안전장치)
- **적용 규칙 요약** — 부품 값을 고를 때 매번 필요한 규칙을 몇 줄로 요약한다. 항목은 스킬이 정하고, 값은 프로젝트가 채운다: ① 글자 크기 바닥선과 예외 자리 ② 역할 한정 토큰 목록(어느 토큰이 어느 자리 전용인지) ③ 화면이 쓰는 간격 단계 허용 목록(디자인 규칙 검사 11번이 읽는다) ④ 큰 글자 배율에서 넘치는 세 자리 대응(SKILL.md 「글자 배율 규칙」) ⑤ 브랜드 색 면 자리 부품 목록 — 한 줄 `BRAND_PARTS:` 뒤에 그 면(소개 화면 띠 등)을 그리는 전용 부품 파일 경로를 공백으로 이어 적는다(디자인 규칙 검사 17번이 읽는다. 개성을 입히기 전에는 줄을 두지 않는다) ⑥ 제목 서체를 쓰는 글자 이름(`t1`·`t2`·`h1` 등) — `TextTheme` 연결로 번지는 Material 부품(상단 바·대화상자 제목)도 함께 적는다. ⑦ 무거운 패키지 목록 — 2-3 파격판이나 견본 지도로 3D·지도 같은 무거운 패키지를 들였을 때만, 두 줄로 적는다(디자인 규칙 검사 18번이 읽는다). `HEAVY_PKGS:` 뒤에 패키지 이름을 공백으로 이어 적고(예: `HEAVY_PKGS: maplibre_gl`), `HEAVY_PARTS:` 뒤에 그 패키지를 부르는 전용 부품 파일 경로를 공백으로 이어 적는다(`HEAVY_PARTS: lib/shared/components/map/map_view.dart`). 들이지 않았으면 두 줄 모두 두지 않는다. 비교안 단계의 경로(`lib/dev/` 아래)는 적지 않는다 — 검사 18번이 `lib/dev/`를 보지 않고, 적어 두면 비교안을 지울 때 이 줄이 남는다. 전체 적용에서 본 부품 경로가 정해진 뒤 채운다. ⑧ 머무는 공간 팔레트 — 2-4 머무는 공간을 적용했을 때만, 두 줄로 적는다(디자인 규칙 검사 19번이 읽는다). `STAY_PALETTE:` 뒤에 물건 제 색을 담은 팔레트 파일 경로를(예: `STAY_PALETTE: lib/core/design/stay/scene_palette.dart`), `STAY_PARTS:` 뒤에 그 파일을 `import`해도 되는 공간 부품 파일 경로를 공백으로 이어 적는다(`STAY_PARTS: lib/shared/components/scene/room_view.dart …`). 적용하지 않았으면 두 줄 모두 두지 않는다. 비교안 단계의 경로(`lib/dev/`·`stay.dart`)는 적지 않는다. 비교안 토큰 이름(`draft…`)과 판 접두 이름(`Bold…`·`Innov…`·`Leap…`·`Stay…`)은 여기 적지 않는다 — 비교안은 고른 뒤 지워지는 임시 이름이다. 왜 여기 두나 — 스킬 본문은 자동 주입이 아니라서, 지시서만 받는 서브 에이전트는 AGENTS.md에 없는 적용 규칙을 알 길이 없다. 그리고 「토큰을 썼는가」만 보는 구조 검사는 「그 토큰을 맞는 자리에 썼는가」(예: 본문에 그림 위 글자용 `caption`을 씀)를 잡지 못한다 — 쓸 때 규칙을 아는 수밖에 없다.

## 5. 다크 모드 대비 노트

지금 다크 모드를 만들지 않더라도, **2층이 교체점이 되도록** 설계해 둔다:
- 색은 반드시 2층 이름을 거치게 (제품 코드에 1층 직접 참조 금지 — 철칙 1·2가 곧 다크 모드 대비다)
- 색 바탕 위 글자는 `on` 짝으로 분리
- 이후 다크 모드 = `AppColors.dark`(그리고 필요하면 `AppShadows.dark`)를 다크용 램프 단계로 채우고 `MaterialApp`의 `darkTheme: buildAppTheme(AppTokens.dark, brightness: Brightness.dark)`를 더하는 작업으로 끝난다. 대비 테스트도 `dark`에 같이 돌린다

## 6. 디자인 시스템 페이지

도입(§1~§4)을 마치면 **「[서비스 이름] 디자인 시스템」 페이지**(서비스 이름을 그대로 넣는다)를 하나 둔다. 실제 토큰과 실제 부품으로 그린 개발용 화면으로, 토큰·부품이 지금 어떻게 보이는지를 한 화면에서 본다. 「규칙 페이지」라고 부르지 않는다.

- **자리** — `lib/dev/design_system/design_system_page.dart`, 개발 빌드 전용 경로 `/dev/design-system`. `lib/dev/`는 `main_dev.dart`와 `main_canvas.dart`에서만 불린다. `main_prod.dart`가 `lib/dev/`를 불러오지 않는 것을 디자인 규칙 검사 13번이 확인한다 — 실서비스 앱에는 이 화면이 아예 들어가지 않는다.
- **목업 캔버스에서도 연다** — 목업 캔버스(iPad 시뮬레이터에 화면을 흐름 순서로 펼쳐 보는 개발용 앱)가 이 페이지를 한 창으로 띄운다. 틀은 하네스의 `.claude/templates/mockup-canvas/`에 있다(쓰는 법은 그 폴더 `README.md`).
- **이 페이지의 코드도 철칙을 지킨다** — 2층 이름만 쓰고 색·간격·글자 크기 숫자를 쓰지 않는다. 본 코드(`lib/features/`·`lib/shared/`)가 `lib/dev/`를 불러오지 않는다.

### 6.1 보여 주는 것

| 영역 | 무엇을 | 어떻게 |
|---|---|---|
| 글자 단계 | 우리 글자 이름(`t1`~`caption`)마다 견본 문장, 크기·굵기·줄 높이, 쓰는 자리 | 견본에 `context.text.*`를 입히고, 그 `TextStyle`의 값을 읽어 숫자로 보인다 |
| 색 역할 | 2층 색 이름마다 견본과 쓰는 자리, `on` 짝의 대비 숫자 | `context.colors`에서 읽고, `contrastPairs`와 `contrastRatio`로 대비를 보인다. 기준 미달이면 표시한다 |
| 간격 | 간격 단계(`s1`~`s16`)마다 견본 막대와 숫자 | `context.space`에서 읽는다 |
| 둥글기 | 용도 이름(`control`·`card`·`sheet`·`pill`)과 숫자 | `context.radius`에서 읽는다 |
| 프레임 예산 | 화면 좌우 여백·누르는 영역 바닥선 등 `AppLayout` 값 | `context.layout`에서 읽는다 |
| 브랜드 | 판마다 자리 하나씩(`BrandPanel`처럼 판 이름으로 부르는 부품 — 대담판 `bold`·혁신판 `innov`·파격판 `leap`). 부품 파일은 `lib/dev/drafts/{판}/brand_panel.dart`의 빈 껍데기로 먼저 만들어 두고 각 판이 자기 것만 채운다. 대담판 자리: 로고 세 크기(상단 바 · 앱 아이콘 크기 · 큰 크기), 브랜드 면 견본(질감이면 가장 나쁜 자리)과 네 대비(면과 바탕 1.2 · 면 위 글자 4.5 · 면 위 회색 글자 4.5 · 면 위 주 버튼 3.0), 제목 서체·전시용 제목 견본(연결 정보에 적은 제목 서체 글자 이름마다), 사진 원본 · 보정 나란히, 앱 아이콘 미리보기(적응형 아이콘의 원·둥근 사각 가림), 움직임 설명(글). 혁신판 자리: 대담판 겉모습을 이어받았다는 표시 + 조작 설명(무엇을·어떻게 하면 무엇이 일어나나)과 대체 경로 목록. 파격판 자리: 위 + 고른 수단이 쓰는 색 견본(2층 이름별)과 수단의 숫자 값 목록. 2-3 개성 입히기 전에는 판 자리 없이 「아직 없음」 한 줄만 둔다 | `context.brand`와 `AppBrand.photoTone`에서 읽고 대비는 `contrastRatio`로 계산해 보인다. 로고는 `assets/brand/`의 SVG 파일. 수단의 숫자 값(원근 값·처음 각도·확대 범위·물건 자리 등)은 값 파일(`lib/dev/drafts/leap/…_values.dart`)을 읽어 보인다 |
| 머무는 공간 | 2-4 머무는 공간의 물건 색(공간 팔레트) 칸과 신호 자리 색·강조색 칸을 나란히 — 팔레트에 강조색과 헷갈리는 색이 없는지 사람이 보는 자리. 그 아래 공간의 숫자 값 목록과 캐릭터 견본. 비교안 동안은 빈 껍데기 `lib/dev/drafts/stay/stay_panel.dart`(`StayPanel`)를 판 토큰 덮개(`Theme(data: draftStayTheme(), …)`)로 감싸 부르고 공간 에이전트가 채운다. 정한 뒤에는 껍데기 대신 본 팔레트를 부른다. 2-4를 하지 않았으면 「아직 없음」 한 줄 | 비교안 동안은 `stay.dart` 안 `Stay{수단}Palette`, 정한 뒤는 `lib/core/design/stay/{수단}_palette.dart`의 `{수단}Palette`에서 읽는다 — 이 페이지는 `lib/dev/` 안이라 검사 19번 대상 밖이다. 강조색은 `context.colors.primary`, 숫자 값은 공간 값 파일에서 읽는다 |
| 움직임 | 길이 세 단계와 곡선 둘을 눌러 보는 견본 | `context.motion` — 동작 줄이기가 켜져 있으면 0으로 보이는 것까지 확인한다 |
| 부품 상태 | 버튼(variant별)·칩·입력칸·탭 등의 평소·누름·비활성·포커스 | 평소와 비활성은 그대로 그린다(`onPressed: null`). 누름은 사람이 눌러 보는 자리, 포커스는 입력칸을 눌러 보는 자리로 둔다 — 상태를 억지로 고정하려고 부품에 개발용 인자를 더하지 않는다 |
| 글자 배율 | 같은 견본을 배율 1.0·1.5·2.0으로 나란히 | 견본 묶음을 `MediaQuery`로 감싸 `textScaler`만 바꾼다 |
| 작은 폰 메모 | 작은 폰에서 무엇이 줄어드는지(목록 한 줄에서 덜어내는 것·격자 열 수·상단 바 행동 수) | 글로 적는다 |

- **값은 코드에 적지 않는다** — 실제 테마에서 읽어 보여 준다. 그래야 이 페이지가 숫자 검사에 걸리지 않고, 토큰 값이 바뀌어도 페이지를 고치지 않고 저절로 따라온다.
- **언제 고치나** — 토큰 값만 바뀌면 손댈 것이 없다. 2층 이름·글자 이름·variant·부품을 새로 더하거나 지우면 이 페이지 목록에도 한 줄 더하거나 지운다 — 부품 인벤토리(§2)에 등록할 때 같이 한다.

### 6.2 정본이 아니라 거울

이 페이지는 토큰의 정본(`foundation.dart`·`semantic.dart`)과 부품 파일을 비춰 보여 주는 거울이다. 값의 정본은 1층, 이름의 정본은 2층, 부품 모양의 정본은 부품 파일이다. 「어디에 어떻게 쓰나」 같은 규칙 결정의 정본은 프로젝트가 정한 기록 자리다 — idea-to-mvp 프로젝트면 `mvp/design-brief.md` 「12. 화면 규칙」. 페이지와 토큰 파일이 다르게 보이면 토큰 파일이 맞다 — 값을 고치려면 1·2층을 고치고, 페이지에는 값을 적지 않는다.

### 6.3 비교안 값을 나란히 보이기

화면 개선(idea-to-mvp 2-2)처럼 토큰 값을 바꿔 보는 동안은 「지금 값」 열과 「비교안 값」 열을 나란히 둔다. 도구는 **비교안만 감싸는 `Theme` 덮개**다.

1. **비교안 값을 `drafts.dart`에 둔다** — 도입 때 만들어 둔 `lib/core/design/drafts.dart`(§1.1 8번)에 비교안 이름의 토큰 한 벌을 둔다. 그 안에서는 **2층 값 바꾸기만** 한다 — 새 토큰 이름은 비교안 안에서 만들지 않는다. **예외 하나: 새 이름이 처음 필요한 비교(2-3 개성 입히기의 브랜드 면·사진 보정·제목 서체·면 위 회색 글자·전시용 제목)는 본 파일에 이름을 먼저 둔다** — `AppBrand`(여덟째 확장)와 `FoundationType.titleFamily`가 도입 때 이미 자리를 잡고 있고, 새로 더하는 `AppBrand.onSurfaceMuted`·`AppTextStyles.display`도 본 값은 「없음」(지금 값과 같게)이라 화면이 달라지지 않는다. 비교안만 `AppTokens.light.copyWith(brand: AppBrand(…))`처럼 진짜 값을 갖는다. 후보 서체 파일과 `pubspec.yaml` 등록 줄도 본 파일에 들어가므로(font-loading.md §4.4) 비교안 보고에 「본 파일을 건드린 곳」으로 적는다. 값은 1층 상수나 1층 상수 기준 계산으로 적는다 — 이 파일은 `lib/core/design/` 안이라 숫자를 써도 검사에 안 걸리지만, 비교안이 1층 원본을 따라가야 고른 뒤 옮기기 쉽다.

   ```dart
   // lib/core/design/drafts.dart — 비교안 — 화면 개선 비교 동안만. bootstrap-project.md §6.3
   import 'foundation.dart';
   import 'semantic.dart';

   final draftHomeB = AppTokens.light.copyWith(
     space: AppSpace.regular.copyWith(s4: FoundationSpace.unit * 5), // 묶음 사이를 한 단계 넓게
     text: AppTextStyles.regular.copyWith(
         b1: AppTextStyles.regular.b1.copyWith(fontSize: FoundationType.b1 + 1)),
   );
   ```


   **판이 여럿이면(idea-to-mvp 2-3) 판마다 파일을 따로 쓴다** — 판 토큰 파일 `lib/core/design/drafts/{판}.dart`(`bold`·`innov`·`leap`)에 그 판의 토큰 한 벌(`AppTokens.light.copyWith(…)`)과 판 접두 새 상수·판 접두 확장을 모두 둔다. `drafts.dart`에는 `export 'drafts/{판}.dart';` 줄만 더한다 — 공유 파일 준비가 판을 띄우기 전에 한 번에 넣는다(세 에이전트가 한 파일을 동시에 고쳐 서로 덮어쓰지 않게). 판 토큰 파일은 `lib/core/design/` 안이라 숫자를 써도 검사 1번에 걸리지 않고 `foundation.dart`를 불러도 검사 2번에 걸리지 않는다. 이름은 판 접두를 붙이고(규칙은 [naming-taxonomy.md](naming-taxonomy.md) §5.2), 판만의 새 2층 이름(여러 겹 면의 둘째 색·수단 안의 색)은 같은 파일 안에 판 접두 확장(예: `BoldBrandExtra extends ThemeExtension`)과 그 접근 이름(`context.boldExtra`)으로 둔다 — 검사 7번이 `lib/core/design/` 밖만 보므로, 접근 이름이 그 파일 안에 있으면 판 폴더의 화면은 `context.*`만 쓴다.

   ```dart
   // lib/core/design/drafts/bold.dart — 판 토큰 파일. 판 토큰 한 벌(draftBold)과 덮개 테마 함수(draftBoldTheme).
   final draftBold = AppTokens.light.copyWith(
     brand: AppBrand(/* … */),
     text: /* 제목 서체를 쓰는 글자 이름의 fontFamily와 display만 바꾼다 */,
   );

   // 기존 확장은 펼쳐 넘기고 판 접두 확장을 얹는다.
   ThemeData draftBoldTheme() {
     final base = buildAppTheme(draftBold);
     return base.copyWith(extensions: [...base.extensions.values, const BoldBrandExtra(/* … */)]);
   }
   ```

   비교안 화면·디자인 시스템 페이지·목업 캔버스 줄은 판 접두 확장까지 들어간 덮개 테마 함수로 감싼다 — `Theme(data: draftBoldTheme(), child: …)`, `CanvasDraft(…, theme: draftBoldTheme())`. `buildAppTheme(draftBold)`로 감싸면 판 접두 확장이 빠진다.

   **경고 — 판 토큰 파일 하나가 틀리면 전체 분석과 `drafts.dart`를 부르는 곳이 함께 깨진다.** `drafts.dart`가 판 파일을 `export`하므로, 한 판의 문법 오류가 `drafts.dart`를 부르는 곳(목업 캔버스 목록·대비 테스트·디자인 시스템 페이지)으로 번진다. `design.dart`는 `drafts.dart`를 내보내지 않으니 본 화면은 깨지지 않는다. 판 점검 테스트는 자기 판 파일만 불러 이 결합을 끊는다. 판 에이전트는 파일을 고칠 때마다 `fvm flutter analyze lib/core/design/drafts/{판}.dart`처럼 자기 판 파일을 지정해 돌려 0건인지 본다.
2. **비교안 화면을 `Theme`으로 감싼다** — 비교안 화면(`lib/dev/drafts/`)과 디자인 시스템 페이지의 「비교안 값」 열을 `Theme(data: buildAppTheme(draftHomeB), child: …)`로 감싼다. 그 아래의 `context.space.s4`·`context.text.b1`이 비교안 값을 읽는다. 페이지는 같은 견본 묶음을 두 번 그린다 — 하나는 그대로(「지금 값」), 하나는 덮개 안(「비교안 값」).
   - **확장을 더할 때는 기존 확장을 펼쳐 넘긴다** — `base.copyWith(extensions: [...base.extensions.values, 판확장])`. `copyWith(extensions: [판확장])`처럼 새 것만 주면 기존 확장이 통째로 사라져 `context.colors`가 null 오류를 낸다(2026-10-22 실험).
   - **시트·대화상자는 덮개 테마를 받지만 `Navigator.push`로 여는 화면은 못 받는다** — `showModalBottomSheet`·`showDialog`는 덮개 안에서 띄우면 같은 테마를 읽는다. `Navigator.push`(`MaterialPageRoute`)로 연 화면은 덮개 밖 기본 테마를 읽어 `context.brand`가 본 값(「없음」)이 된다. 그 화면 안에서 `Theme`으로 다시 감싸거나(`InheritedTheme.captureAll(context, 화면)`으로 현재 테마를 실어 보낸다), 비교안 전체를 `MaterialApp(builder:)`로 감싼다.
3. **고른 뒤** — 고른 비교안의 바뀐 값을 `semantic.dart`(필요하면 `foundation.dart`)로 옮기고 `drafts.dart`의 그 비교안을 지운다. 머리 주석은 남겨 다음 비교 때 쓴다. 페이지는 「지금 값」 하나로 돌아간다. 고르지 않은 비교안은 그 비교안 화면을 지울 때 같이 지운다(idea-to-mvp는 3단계 화면 대조가 끝날 때). 본 코드(`lib/features/`·`lib/shared/`)에는 비교안 덮개가 남지 않아야 한다.
