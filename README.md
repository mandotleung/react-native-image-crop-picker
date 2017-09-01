# Fork from https://github.com/Elyx0/react-native-document-picker
- Update iOS to support copy 360 photo metadata
- Check is 360 photo
- Add options return source image data instead of compress


### Request Object(Customized)

| Property                                |                   Type                   | Description                              |
| --------------------------------------- | :--------------------------------------: | :--------------------------------------- |
| copyMetaData                                |           bool (default false)           | (apply to image only) Enable or disable copyMetaData. When `compressImage = false`, this options will be ignored          |
| checkProjectionType                                   |                  bool (default false)                  |(apply to image only)  If enable this options, it will check photo metadata and append the `is360Photo` in response object |
| compressImage                                  |                  bool (default ture)                  | (apply to image only) Add option to disable the compress logic and return the source image picked  |

### Response Object

| Property                  |  Type  | Description                              |
| ------------------------- | :----: | :--------------------------------------- |
| is360Photo                      | string | (apply to image only) "Y" or "N", identify logic refer to https://www.facebook.com/notes/eric-cheng/editing-360-photos-injecting-metadata/10156930564975277                  |
| mime                      | string | (apply to image only) updated a little bit. if `compressImage = false`, it will use `image/` + `jpg` , `png`..etc. If file no extension, it will use UTI |
