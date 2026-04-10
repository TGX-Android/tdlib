//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2020
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//

plugins {
    id(libs.plugins.android.library.get().pluginId)
    // Add
    //alias(libs.plugins.kotlin.android)
    //id("tgx-module")
}

dependencies {
    implementation(libs.androidx.annotation)
}

android {
    // Add
    compileSdk {
        version = release(36) {
            minorApiLevel = 1
        }
    }

    // Add
    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/libs")
        }
    }

  namespace = "org.drinkless.tdlib"

  defaultConfig {
    consumerProguardFiles("consumer-rules.pro")
  }
}
