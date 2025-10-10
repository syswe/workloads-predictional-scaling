#!/bin/bash

# Makale bölümlerini birleştirme scripti

echo "Makale bölümleri birleştiriliyor..."

# Çıktı dosyası
OUTPUT="article-complete.tex"

# main.tex'in başlangıç kısmını al (Bulgular bölümüne kadar)
head -n 200 main.tex > $OUTPUT

# Bulgular bölümünü yeniden yaz
cat >> $OUTPUT << 'EOF'

\section{Bulgular (Results)}

Bu bölümde, yüksek lisans tezi kapsamında elde edilen temel bulgular özetlenmekte ve mevcut çalışmada gerçekleştirilen çevrimdışı ve çevrimiçi kıyaslama sonuçları detaylandırılmaktadır.

\subsection{Yüksek Lisans Tezi Bulguları (Master Thesis Findings)}

Yüksek lisans tezi çalışmasında, 600 farklı senaryo üzerinde 2 milyondan fazla veri noktası ile kapsamlı değerlendirme gerçekleştirilmiştir [15]. Örüntü-spesifik model seçimi yaklaşımı ile evrensel modellere kıyasla \%37,4 ortalama MAE iyileştirmesi elde edilmiştir. Tablo~\ref{tab:pattern-model}'de gösterildiği üzere, her örüntü tipi için optimal model belirlenmiş ve kazanma oranları hesaplanmıştır.

LLM entegrasyonu değerlendirmesinde, Gemini 2.5 Pro modeli \%96,7 genel doğruluk ile en başarılı sonucu vermiştir. Çok modlu analiz yetenekleri sayesinde, hem metin tabanlı CSV hem de görsel grafik analizi ile yük örüntüleri başarıyla tanınmıştır. Model eğitim süreleri 0,02-0,61 saniye, bellek kullanımı 42-210 MB aralığında ölçülmüştür.

Tablo~\ref{tab:llm-performance}'de yüksek lisans tezi kapsamında elde edilen temel performans metrikleri özetlenmektedir.

\begin{table}[h]
    \centering
    \caption{Yüksek lisans tezi temel performans metrikleri (Master thesis key performance metrics).}
    \label{tab:llm-performance}
    \begin{tabular}{@{}lcc@{}}
        \toprule
        Metrik & Değer & Birim \\
        \midrule
        LLM Genel Doğruluk & 96,7 & \% \\
        Örüntü-Spesifik İyileştirme & 37,4 & \% \\
        Model Eğitim Süresi & 0,02-0,61 & s \\
        Bellek Kullanımı & 42-210 & MB \\
        Toplam Veri Noktası & 2M+ & - \\
        Senaryo Çeşitliliği & 600 & - \\
        \bottomrule
    \end{tabular}
\end{table}

\subsection{Çevrimdışı (Offline) Kıyaslama Sonuçları (Offline Benchmark Results)}

Mevcut çalışmada, operatöre entegre edilen modellerin performansları sentetik veri üzerinde değerlendirilmiştir. 48 saat eğitim ve 12 saat test verisi kullanılarak her model için RMSE, MAE ve MAPE metrikleri hesaplanmıştır. Tablo~\ref{tab:offline}'de çevrimdışı kıyaslama sonuçları özetlenmektedir.

GBDT modeli, 1,98 RMSE ve 1,56 MAE değerleri ile en düşük hata oranlarını sağlamıştır. XGBoost modeli de benzer performans göstererek 2,31 RMSE ve 1,85 MAE değerlerine ulaşmıştır. CatBoost modelinin daha yüksek hata üretmesi (5,55 RMSE, 4,56 MAE), özellik mühendisliğinin sınırlı olduğu sentetik veride modelin kapasitesinin tam kullanılamamasıyla ilişkilidir.

VAR modelinin sentetik tek değişkenli veride aşırı yüksek hatalar ürettiği gözlemlenmiştir ($5,75\times10^{18}$ RMSE). Model, çok değişkenli girdiler için tasarlandığından bu durum beklenen bir sonuçtur. Gerçek dünya uygulamalarında, VAR modelinin ek metriklerle (CPU, bellek, ağ trafiği vb.) beslenmesi önerilmektedir.

\begin{table}[h]
    \centering
    \caption{Çevrimdışı deneylerde raporlanan hata ölçümleri (Offline benchmark error metrics).}
    \label{tab:offline}
    \begin{tabular}{@{}lccc@{}}
        \toprule
        Model & RMSE & MAE & MAPE (\%) \\
        \midrule
        GBDT & 1,98 & 1,56 & 6,13 \\
        XGBoost & 2,31 & 1,85 & 7,42 \\
        CatBoost & 5,55 & 4,56 & 21,36 \\
        VAR & $5,75\times10^{18}$ & $3,59\times10^{18}$ & $1,35\times10^{19}$ \\
        \bottomrule
    \end{tabular}
\end{table}

EOF

# Diğer bölümleri ekle
cat sections/03-results-continued.tex >> $OUTPUT
cat sections/04-discussion.tex >> $OUTPUT
cat sections/05-symbols.tex >> $OUTPUT
cat sections/06-conclusions.tex >> $OUTPUT
cat sections/07-acknowledgments-references.tex >> $OUTPUT

echo "Birleştirme tamamlandı: $OUTPUT"
echo "PDF oluşturmak için: pdflatex $OUTPUT"
