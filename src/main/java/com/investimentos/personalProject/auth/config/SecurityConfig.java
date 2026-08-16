package com.investimentos.personalProject.auth.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;

// Essa classe tem configuracões do Spring
@Configuration
public class SecurityConfig {

    // Criptografa e valida as senhas utilizando BCrypt
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {

        // API REST com JWT não utiliza proteção CSRF baseada em sessão
        http.csrf(csrf -> csrf.disable());

        // JWT torna a autenticação stateless, sem sessão no servidor
        http.sessionManagement(session ->
                session.sessionCreationPolicy(
                        SessionCreationPolicy.STATELESS
                )
        );

        // Login não precisa de autenticação
        // Demais endpoints precisam de autenticação
        http.authorizeHttpRequests(auth -> auth
                .requestMatchers("/auth/login", "/auth/register").permitAll()
                .anyRequest().authenticated()
        );

        return http.build();
    }
}