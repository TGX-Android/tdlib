//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2020
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//

plugins {
    id("com.android.library")
    id("module-plugin")
}

dependencies {
    implementation("androidx.annotation:annotation:${LibraryVersions.ANNOTATIONS}")
}

android {
  namespace = "org.drinkless.tdlib"
}
