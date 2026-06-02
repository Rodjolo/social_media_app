# Реализация сбора данных

Эту схему удобно использовать для слайда презентации. Она показывает, какие данные собирает приложение, где они сохраняются и как затем используются в рекомендательной системе.

```mermaid
%%{init: {"theme": "base", "themeVariables": {"background": "#FFFFFF", "fontFamily": "Arial, sans-serif", "fontSize": "18px", "primaryColor": "#FFFFFF", "primaryTextColor": "#0F172A", "primaryBorderColor": "#1D4ED8", "secondaryColor": "#F1F5F9", "secondaryTextColor": "#0F172A", "secondaryBorderColor": "#334155", "tertiaryColor": "#ECFDF5", "tertiaryTextColor": "#064E3B", "tertiaryBorderColor": "#059669", "lineColor": "#334155", "textColor": "#0F172A", "edgeLabelBackground": "#FFFFFF"}}}%%
flowchart LR
    User["Пользователь"] --> Register["Регистрация и вход"]
    User --> Profile["Профиль и подписки"]
    User --> PostsAction["Посты, лайки, комментарии"]
    User --> MovieAction["Оценки и лайки фильмов"]

    Register --> Users[("users")]
    Profile --> Users
    PostsAction --> Posts[("posts")]
    PostsAction --> Media[("media")]
    MovieAction --> Ratings[("ratings")]

    MovieLens["MovieLens\nmovies.csv / ratings.csv / links.csv"] --> ImportMovies["Импорт каталога"]
    TMDB["TMDB\nпостеры / описания / жанры"] --> ImportMovies
    ImportMovies --> Movies[("movies")]

    Ratings --> Service["Local recommendation service\n/status /rebuild"]
    Movies --> Service
    MovieLens --> Service

    Service --> Pipeline["Python pipeline\nitem-based collaborative filtering"]
    Pipeline --> Recommendations[("recommendations")]
    Pipeline --> Reports["validation / comparison / status reports"]

    Recommendations --> RecScreen["Экран рекомендаций"]
    Reports --> AdminPanel["Админ-панель рекомендаций"]

    classDef source fill:#EFF6FF,stroke:#2563EB,color:#0F172A
    classDef action fill:#FFFFFF,stroke:#334155,color:#0F172A
    classDef db fill:#ECFDF5,stroke:#059669,color:#064E3B
    classDef report fill:#FFFBEB,stroke:#D97706,color:#78350F

    class User,MovieLens,TMDB source
    class Register,Profile,PostsAction,MovieAction,ImportMovies,Service,Pipeline,RecScreen,AdminPanel action
    class Users,Posts,Media,Ratings,Movies,Recommendations db
    class Reports report
```

## Краткое объяснение

1. Пользовательские действия формируют данные в `users`, `posts`, `media` и `ratings`.
2. Каталог фильмов создается из MovieLens и обогащается TMDB-метаданными.
3. Оценки из `ratings` становятся входом для локального сервиса рекомендаций.
4. Python-пайплайн строит персональные рекомендации и сохраняет их в `recommendations`.
5. Отчеты качества используются в админ-панели для демонстрации и проверки результата.
