// Site-wide configuration
export const siteConfig = {
  // Site metadata
  name: "Astro Blog",
  title: "Astro Blog",
  description: "A modern blog built with Astro",
  
  // Navigation
  navigation: {
    home: "Home",
    posts: "Posts",
    contact: "Contact",
    comments: "Comments",
  },
  
  // Hero Section
  hero: {
    prefix: "I am",
    name: "Sebastián Pérez Herrera",
    intro: "Soy un estudiante de ingeniería de sistemas, de la universidad El Bosque en su quinto semestre, apasionado por aprender cada día nuevos conceptos y tecnologías.\nBienvenido a mi portafolio!",
    avatar: "/image/Imagen_presentacion.png",
    buttons: {
      viewPosts: "View Posts",
      contactMe: "Contact Me",
    },
    socialLinks: [
      { name: "LinkedIn", icon: "/svg/linkedin.svg", url: "https://www.linkedin.com/in/sebastian-perez-642403327/" },
      { name: "Facebook", icon: "/svg/instagram.svg", url: "https://www.instagram.com/sebssprz/" },
      { name: "GitHub", icon: "/svg/github.svg", url: "https://github.com/sebaas364" },
    ],
  },
  
  // About Section
  about: {
    title: "Sobre mi",
    text: "¡Hola!, Soy sebastian\n soy un apasionado estudiante de ingeniería de sistemas, que le gusta el desarrollo. Tengo una solida comprensión de los conceptos fundamentales de distintos temas respecto a mi carrera, lo que me permite diseñar y optimizar soluciones eficientes y escalables. Me interesa seguir aprendiendo y perfeccionando mis habilidades con el objetivo de poder contribuir en proyectos.",
  },
  
  // Contact Page
  contact: {
    title: "Get In Touch",
    subtitle: "I'm always open to discussing new projects, creative ideas, or opportunities to be part of your visions.",
    info: {
      email: {
        label: "Email",
        value: "tom@example.com",
        link: "mailto:tom@example.com",
      },
      phone: {
        label: "Phone",
        value: "+1 (234) 567-890",
        link: "tel:+1 (234) 567-890",
      },
      location: {
        label: "Location",
        value: "San Francisco, CA",
      },
    },
    followMe: {
      title: "Follow Me",
      links: [
        { name: "Twitter", icon: "/svg/twitter.svg", url: "https://x.com/astrodotbuild" },
        { name: "LinkedIn", icon: "/svg/linkedin.svg", url: "https://www.linkedin.com/company/astrodotbuild" },
        { name: "Facebook", icon: "/svg/facebook.svg", url: "https://www.facebook.com/astrodotbuild" },
        { name: "GitHub", icon: "/svg/github.svg", url: "https://github.com/tomcomtang/astro-cartoon-portfolio" },
      ],
    },
    footerText: [
      "I typically respond to messages within 24 hours during business days.",
      "Looking forward to hearing from you! 🚀",
    ],
    messageButton: "💬 Leave a Message",
  },
  
  // Footer
  footer: {
    copyright: "© 2025 Someone. All rights reserved.",
    links: [
      { text: "Privacy Policy", url: "#" },
      { text: "Terms of Service", url: "#" },
      { text: "Sitemap", url: "#" },
    ],
    github: {
      text: "Star this project on Github",
      url: "https://github.com/tomcomtang/astro-cartoon-portfolio",
    },
  },
  
  // Posts Page
  posts: {
    title: "Blog Posts",
    subtitle: "Explore our latest articles on web development, design, and technology",
    searchPlaceholder: "Search posts...",
  },
  
  // Comments Page
  comments: {
    title: "Comments & Discussion",
    subtitle: "Share your thoughts, questions, or suggestions here. Let's connect and discuss!",
    guidelines: {
      title: "Community Guidelines",
      items: [
        "Be respectful and constructive in your comments",
        "No spam, self-promotion, or advertising allowed",
        "No personal attacks, hate speech, or harassment",
        "Stay on topic and keep discussions relevant",
        "No inappropriate, offensive, or illegal content",
        "Use clear, friendly, and inclusive language",
      ],
    },
  },
};

