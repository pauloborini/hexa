// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Foundation

struct NotchFilesStrings {
    let saved: String
    let downloadsTitle: String
    let downloadsDescription: String
    let downloadsHint: String
    let chooseFolder: String
    let folderUnavailable: String
    let waiting: String
    let inProgress: String
    let totalUnknown: String
    let completed: String
    let clearFolder: String
    let optimizeMedia: String
    let optimizeDropHint: String
    let mediaDropHint: String
    let resumeMedia: String
}

extension FeatureStrings {
    static func notchFiles(_ language: AppLanguage) -> NotchFilesStrings {
        switch language {
        case .enUS: return NotchFilesStrings(
            saved: "Saved",
            downloadsTitle: "Downloads",
            downloadsDescription: "See files arriving in a folder you choose, directly in the Dynamic Island.",
            downloadsHint: "Choose the folder where your browser saves downloads. Only that folder is watched.",
            chooseFolder: "Choose Folder…",
            folderUnavailable: "This folder is unavailable. Choose it again to restore access.",
            waiting: "No files in this folder",
            inProgress: "Downloading",
            totalUnknown: "Total size unavailable",
            completed: "Download complete",
            clearFolder: "Forget Folder",
            optimizeMedia: "Optimize media",
            optimizeDropHint: "Drag images or one video onto the island to choose how to save an optimized copy.",
            mediaDropHint: "Drop images or one video here",
            resumeMedia: "Return to media")
        case .ptBR: return NotchFilesStrings(
            saved: "Salvo",
            downloadsTitle: "Downloads",
            downloadsDescription: "Veja os arquivos chegando em uma pasta escolhida, direto no Dynamic Island.",
            downloadsHint: "Escolha a pasta onde seu navegador salva os downloads. Só essa pasta será acompanhada.",
            chooseFolder: "Escolher pasta…",
            folderUnavailable: "A pasta está indisponível. Escolha novamente para recuperar o acesso.",
            waiting: "Nenhum arquivo nesta pasta",
            inProgress: "Baixando",
            totalUnknown: "Tamanho total indisponível",
            completed: "Download concluído",
            clearFolder: "Esquecer pasta",
            optimizeMedia: "Otimizar mídia",
            optimizeDropHint: "Arraste imagens ou um vídeo até a ilha para escolher como salvar uma cópia otimizada.",
            mediaDropHint: "Solte imagens ou um vídeo aqui",
            resumeMedia: "Voltar à mídia")
        case .es: return NotchFilesStrings(
            saved: "Guardado",
            downloadsTitle: "Descargas",
            downloadsDescription: "Ve los archivos que llegan a una carpeta elegida, directamente en el Dynamic Island.",
            downloadsHint: "Elige la carpeta donde tu navegador guarda las descargas. Solo se supervisa esa carpeta.",
            chooseFolder: "Elegir carpeta…",
            folderUnavailable: "La carpeta no está disponible. Elígela de nuevo para recuperar el acceso.",
            waiting: "No hay archivos en esta carpeta",
            inProgress: "Descargando",
            totalUnknown: "Tamaño total no disponible",
            completed: "Descarga completada",
            clearFolder: "Olvidar carpeta",
            optimizeMedia: "Optimizar contenido",
            optimizeDropHint: "Arrastra imágenes o un vídeo a la isla para elegir cómo guardar una copia optimizada.",
            mediaDropHint: "Suelta imágenes o un vídeo aquí",
            resumeMedia: "Volver al contenido multimedia")
        case .sk: return NotchFilesStrings(
            saved: "Uložené",
            downloadsTitle: "Stiahnuté",
            downloadsDescription: "Sledujte súbory prichádzajúce do vybraného priečinka priamo v Dynamic Island.",
            downloadsHint: "Vyberte priečinok, kam váš prehliadač ukladá stiahnuté súbory. Sleduje sa iba tento priečinok.",
            chooseFolder: "Vybrať priečinok…",
            folderUnavailable: "Tento priečinok nie je dostupný. Vyberte ho znova, aby ste obnovili prístup.",
            waiting: "V tomto priečinku nie sú žiadne súbory",
            inProgress: "Sťahovanie",
            totalUnknown: "Celková veľkosť nie je dostupná",
            completed: "Sťahovanie dokončené",
            clearFolder: "Zabudnúť priečinok",
            optimizeMedia: "Optimalizovať médiá",
            optimizeDropHint: "Presuňte obrázky alebo jedno video na Dynamic Island a vyberte, ako uložiť optimalizovanú kópiu.",
            mediaDropHint: "Sem pustite obrázky alebo jedno video",
            resumeMedia: "Späť na médiá")
        case .de: return NotchFilesStrings(
            saved: "Gesichert",
            downloadsTitle: "Downloads",
            downloadsDescription: "Sieh direkt im Dynamic Island, welche Dateien in einem ausgewählten Ordner ankommen.",
            downloadsHint: "Wähle den Ordner, in dem dein Browser Downloads sichert. Nur dieser Ordner wird beobachtet.",
            chooseFolder: "Ordner auswählen…",
            folderUnavailable: "Der Ordner ist nicht verfügbar. Wähle ihn erneut aus, um den Zugriff wiederherzustellen.",
            waiting: "Keine Dateien in diesem Ordner",
            inProgress: "Wird geladen",
            totalUnknown: "Gesamtgröße nicht verfügbar",
            completed: "Download abgeschlossen",
            clearFolder: "Ordner vergessen",
            optimizeMedia: "Medien optimieren",
            optimizeDropHint: "Ziehe Bilder oder ein Video auf die Insel, um eine optimierte Kopie nach Wunsch zu sichern.",
            mediaDropHint: "Bilder oder ein Video hier ablegen",
            resumeMedia: "Zurück zu Medien")
        case .fr: return NotchFilesStrings(
            saved: "Enregistré",
            downloadsTitle: "Téléchargements",
            downloadsDescription: "Voyez les fichiers arriver dans un dossier choisi, directement dans le Dynamic Island.",
            downloadsHint: "Choisissez le dossier où votre navigateur enregistre les téléchargements. Seul ce dossier est suivi.",
            chooseFolder: "Choisir un dossier…",
            folderUnavailable: "Ce dossier est indisponible. Choisissez-le à nouveau pour rétablir l’accès.",
            waiting: "Aucun fichier dans ce dossier",
            inProgress: "Téléchargement",
            totalUnknown: "Taille totale indisponible",
            completed: "Téléchargement terminé",
            clearFolder: "Oublier le dossier",
            optimizeMedia: "Optimiser les médias",
            optimizeDropHint: "Faites glisser des images ou une vidéo sur l’îlot pour choisir comment enregistrer une copie optimisée.",
            mediaDropHint: "Déposez des images ou une vidéo ici",
            resumeMedia: "Revenir aux médias")
        case .it: return NotchFilesStrings(
            saved: "Salvato",
            downloadsTitle: "Download",
            downloadsDescription: "Vedi i file in arrivo in una cartella scelta, direttamente nel Dynamic Island.",
            downloadsHint: "Scegli la cartella in cui il browser salva i download. Viene monitorata solo quella cartella.",
            chooseFolder: "Scegli cartella…",
            folderUnavailable: "La cartella non è disponibile. Sceglila di nuovo per ripristinare l’accesso.",
            waiting: "Nessun file in questa cartella",
            inProgress: "Download in corso",
            totalUnknown: "Dimensione totale non disponibile",
            completed: "Download completato",
            clearFolder: "Dimentica cartella",
            optimizeMedia: "Ottimizza contenuti",
            optimizeDropHint: "Trascina immagini o un video sull’isola per scegliere come salvare una copia ottimizzata.",
            mediaDropHint: "Rilascia qui immagini o un video",
            resumeMedia: "Torna ai contenuti multimediali")
        case .ru: return NotchFilesStrings(
            saved: "Сохранено",
            downloadsTitle: "Загрузки",
            downloadsDescription: "Следите за файлами, поступающими в выбранную папку, прямо в вырезе.",
            downloadsHint: "Выберите папку, в которую браузер сохраняет загрузки. Отслеживается только эта папка.",
            chooseFolder: "Выбрать папку…",
            folderUnavailable: "Папка недоступна. Выберите её снова, чтобы восстановить доступ.",
            waiting: "В этой папке нет файлов",
            inProgress: "Загрузка",
            totalUnknown: "Общий размер недоступен",
            completed: "Загрузка завершена",
            clearFolder: "Забыть папку",
            optimizeMedia: "Оптимизировать медиа",
            optimizeDropHint: "Перетащите изображения или одно видео на островок, чтобы выбрать параметры сохранения оптимизированной копии.",
            mediaDropHint: "Перетащите сюда изображения или одно видео",
            resumeMedia: "Вернуться к медиа")
        case .tr: return NotchFilesStrings(
            saved: "Kaydedildi",
            downloadsTitle: "İndirmeler",
            downloadsDescription: "Seçtiğiniz klasöre gelen dosyaları doğrudan çentikte görün.",
            downloadsHint: "Tarayıcınızın indirmeleri kaydettiği klasörü seçin. Yalnızca bu klasör izlenir.",
            chooseFolder: "Klasör seç…",
            folderUnavailable: "Bu klasöre erişilemiyor. Erişimi yeniden sağlamak için tekrar seçin.",
            waiting: "Bu klasörde dosya yok",
            inProgress: "İndiriliyor",
            totalUnknown: "Toplam boyut bilinmiyor",
            completed: "İndirme tamamlandı",
            clearFolder: "Klasörü unut",
            optimizeMedia: "Medyayı iyileştir",
            optimizeDropHint: "Görüntüleri veya tek bir videoyu adaya sürükleyin ve iyileştirilmiş kopyayı nasıl kaydedeceğinizi seçin.",
            mediaDropHint: "Görüntüleri veya tek bir videoyu buraya bırakın",
            resumeMedia: "Medyaya dön")
        case .ja: return NotchFilesStrings(
            saved: "保存済み",
            downloadsTitle: "ダウンロード",
            downloadsDescription: "選択したフォルダに届くファイルをDynamic Islandで確認できます。",
            downloadsHint: "ブラウザのダウンロード保存先フォルダを選択してください。このフォルダのみを監視します。",
            chooseFolder: "フォルダを選択…",
            folderUnavailable: "このフォルダは利用できません。アクセスを復元するには、もう一度選択してください。",
            waiting: "このフォルダにはファイルがありません",
            inProgress: "ダウンロード中",
            totalUnknown: "合計サイズは不明です",
            completed: "ダウンロード完了",
            clearFolder: "フォルダの選択を解除",
            optimizeMedia: "メディアを最適化",
            optimizeDropHint: "画像または1本の動画をアイランドにドラッグして、最適化したコピーの保存方法を選びます。",
            mediaDropHint: "画像または1本の動画をここにドロップ",
            resumeMedia: "メディアに戻る")
        case .ko: return NotchFilesStrings(
            saved: "저장됨",
            downloadsTitle: "다운로드",
            downloadsDescription: "선택한 폴더에 도착하는 파일을 Dynamic Island에서 바로 확인하세요.",
            downloadsHint: "브라우저가 다운로드를 저장하는 폴더를 선택하세요. 해당 폴더만 확인합니다.",
            chooseFolder: "폴더 선택…",
            folderUnavailable: "이 폴더를 사용할 수 없습니다. 접근 권한을 복원하려면 다시 선택하세요.",
            waiting: "이 폴더에 파일 없음",
            inProgress: "다운로드 중",
            totalUnknown: "전체 크기를 알 수 없음",
            completed: "다운로드 완료",
            clearFolder: "폴더 선택 해제",
            optimizeMedia: "미디어 최적화",
            optimizeDropHint: "이미지 또는 동영상 하나를 아일랜드로 드래그하면 최적화된 사본의 저장 방식을 선택할 수 있습니다.",
            mediaDropHint: "이미지 또는 동영상 하나를 여기에 놓으세요",
            resumeMedia: "미디어로 돌아가기")
        case .zhHans: return NotchFilesStrings(
            saved: "已保存",
            downloadsTitle: "下载",
            downloadsDescription: "直接在Dynamic Island中查看文件下载到所选文件夹的情况。",
            downloadsHint: "选择浏览器保存下载文件的文件夹。仅监视此文件夹。",
            chooseFolder: "选择文件夹…",
            folderUnavailable: "此文件夹不可用。请重新选择以恢复访问。",
            waiting: "此文件夹中没有文件",
            inProgress: "正在下载",
            totalUnknown: "总大小未知",
            completed: "下载完成",
            clearFolder: "忘记文件夹",
            optimizeMedia: "优化媒体",
            optimizeDropHint: "将图片或一个视频拖到灵动岛，选择如何保存优化后的副本。",
            mediaDropHint: "将图片或一个视频拖放到这里",
            resumeMedia: "返回媒体")
        case .zhTW: return NotchFilesStrings(
            saved: "已儲存",
            downloadsTitle: "下載",
            downloadsDescription: "直接在Dynamic Island中查看檔案下載到所選檔案夾的情況。",
            downloadsHint: "選擇瀏覽器儲存下載檔案的檔案夾。只會監看此檔案夾。",
            chooseFolder: "選擇檔案夾…",
            folderUnavailable: "此檔案夾無法使用。請重新選擇以恢復存取。",
            waiting: "此檔案夾中沒有檔案",
            inProgress: "正在下載",
            totalUnknown: "總大小未知",
            completed: "下載完成",
            clearFolder: "忘記檔案夾",
            optimizeMedia: "最佳化媒體",
            optimizeDropHint: "將圖片或一部影片拖曳到動態島，選擇如何儲存最佳化的副本。",
            mediaDropHint: "將圖片或一部影片拖放到這裡",
            resumeMedia: "返回媒體")
        case .zhHK: return NotchFilesStrings(
            saved: "已儲存",
            downloadsTitle: "下載",
            downloadsDescription: "直接在Dynamic Island中查看檔案下載到所選資料夾的情況。",
            downloadsHint: "選擇瀏覽器儲存下載檔案的資料夾。只會監察此資料夾。",
            chooseFolder: "選擇資料夾…",
            folderUnavailable: "此資料夾無法使用。請重新選擇以恢復取用。",
            waiting: "此資料夾中沒有檔案",
            inProgress: "正在下載",
            totalUnknown: "總大小不詳",
            completed: "下載完成",
            clearFolder: "忘記資料夾",
            optimizeMedia: "最佳化媒體",
            optimizeDropHint: "將圖片或一段影片拖曳到動態島，選擇如何儲存最佳化的副本。",
            mediaDropHint: "將圖片或一段影片拖放到這裡",
            resumeMedia: "返回媒體")
        case .uk: return NotchFilesStrings(
            saved: "Збережено",
            downloadsTitle: "Завантаження",
            downloadsDescription: "Стежте за файлами, які надходять до вибраної папки, прямо у Dynamic Island.",
            downloadsHint: "Виберіть папку, куди ваш браузер зберігає завантаження. Відстежується лише ця папка.",
            chooseFolder: "Вибрати папку…",
            folderUnavailable: "Ця папка недоступна. Виберіть її знову, щоб відновити доступ.",
            waiting: "У цій папці немає файлів",
            inProgress: "Завантаження",
            totalUnknown: "Загальний розмір недоступний",
            completed: "Завантаження завершено",
            clearFolder: "Забути папку",
            optimizeMedia: "Оптимізувати медіа",
            optimizeDropHint: "Перетягніть зображення або одне відео на острівець, щоб вибрати, як зберегти оптимізовану копію.",
            mediaDropHint: "Перетягніть сюди зображення або одне відео",
            resumeMedia: "Повернутися до медіа")
        }
    }
}
