# Fork from https://github.com/Elyx0/react-native-document-picker
- (iOS only)support copy 360 photo metadata
- (iOS only)Add options return source image data instead of compress
- Check is 360 photo
- return source image md5 (iOS - not the actual md5 of returned image. Becuase I need the md5 of the picked image for verify duplicate selection)


### Request Object(Customized)

| Property                                |                   Type                   | Description                              |
| --------------------------------------- | :--------------------------------------: | :--------------------------------------- |
| copyMetaData                                |           bool (default false)           | (apply to image only) Enable or disable copyMetaData. When `compressImage = false`, this options will be ignored          |
| checkProjectionType                                   |                  bool (default false)                  |(apply to image only)  If enable this options, it will check photo metadata and append the `is360Photo` in response object |
| compressImage  (iOS only, Android will not compress image if no `compressXXXXX` options)                                |                  bool (default ture)                  | (apply to image only) Add option to disable the compress logic and return the source image picked  |

### Response Object

| Property                  |  Type  | Description                              |
| ------------------------- | :----: | :--------------------------------------- |
| is360Photo                      | string | (apply to image only) "Y" or "N", identify logic refer to https://www.facebook.com/notes/eric-cheng/editing-360-photos-injecting-metadata/10156930564975277                  |
| mime                      | string | (apply to image only) updated a little bit. if `compressImage = false`, it will use `image/` + `jpg` , `png`..etc. If file no extension, it will use UTI |
| md5                      | string | (apply to image only) iOS - not the actual md5 of returned image. Becuase I need the md5 of the picked image for verify duplicate selection |
