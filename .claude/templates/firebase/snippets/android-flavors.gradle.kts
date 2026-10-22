// android/app/build.gradle.kts의 android { … } 블록 안, defaultConfig { … } 바로 아래에 넣습니다.
// 같은 코드로 앱 두 벌 — 개발용(dev)·실서비스용(prod).
// 패키지 이름이 달라 한 폰에 둘 다 깔 수 있고, 홈 화면 이름도 다릅니다.

    // resValue(앱 이름)를 쓰려면 이 기능을 켜야 합니다(안드로이드 빌드 도구 최근 판은 기본으로 꺼 둠).
    buildFeatures {
        resValues = true
    }
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "<앱 이름> 개발")
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "<앱 이름>")
        }
    }
