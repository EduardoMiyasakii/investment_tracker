package com.investimentos.personalProject.auth.service;

import com.investimentos.personalProject.auth.dto.LoginRequest;
import com.investimentos.personalProject.auth.dto.LoginResponse;
import com.investimentos.personalProject.auth.dto.RegisterRequest;
import com.investimentos.personalProject.auth.entity.Role;
import com.investimentos.personalProject.auth.entity.User;
import com.investimentos.personalProject.auth.repository.UserRepository;
import com.investimentos.personalProject.auth.security.JwtService;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.UUID;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    // Instanciando tudo que é necessário
    public AuthService(UserRepository userRepository,
                       PasswordEncoder passwordEncoder, JwtService jwtService){

        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
    }

    public LoginResponse login(LoginRequest loginRequest){

        // Vendo se o usuário existe no banco
        User user = userRepository.findByEmail(loginRequest.email())
                .orElseThrow(() -> new RuntimeException("Email ou senha inválidos"));

        // Verificando se o hash das senhas bate
        if(!passwordEncoder.matches(loginRequest.password(),
                user.getPasswordHash())){
            throw new RuntimeException("Email ou senha inválidos");
        }

        String token = jwtService.generateToken(user);

        return new LoginResponse(token);
    }

    public void register(RegisterRequest registerRequest){

        if(userRepository.existsByEmail(registerRequest.email())){
            throw new RuntimeException("Email já cadastrado");
        }

        User user = new User(
                UUID.randomUUID().toString(),
                registerRequest.name(),
                registerRequest.email(),
                passwordEncoder.encode(registerRequest.password()),
                Role.USER,
                LocalDateTime.now()
        );

        userRepository.save(user);
    }
}
