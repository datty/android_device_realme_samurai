#
# Copyright (C) 2019-2020 The MoKee Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# The IFAAService app is now provided by hardware/oplus/packages/IFAAService.
# Building it here too caused a kati duplicate (MODULE.TARGET.APPS.IFAAService
# already defined by hardware/oplus/packages/IFAAService). The device-specific
# "ifaamanager" java library (Android.bp) is unique to this tree and is kept;
# the app sources here (src/, AndroidManifest.xml) are retained for reference
# only and are no longer built.
